//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 28/05/2018
// Created by: Huni
//


#import "mtha_splay_tree.h"
#import <errno.h>
#import <sys/mman.h>
#import <unistd.h>
#import "mtha_file_utils.h"
#import "mtha_inner_allocate.h"


mtha_splay_tree_node mtha_splay_node_init(uint64_t addr, uint64_t stackid_and_flags, uint64_t category_and_size, uint64_t parent) {
    mtha_splay_tree_node node;
    node.addr_cnt.addr = addr;
    node.addr_cnt.cnt = 1;
    node.category_and_size = category_and_size;
    node.stackid_and_flags = stackid_and_flags;
    node.index.parent = (uint32_t)parent;
    node.index.left = 0;
    node.index.right = 0;
    return node;
}

mtha_splay_tree *mtha_splay_tree_read_from_mmapfile(const char *path) {
    FILE *fp = fopen(path, "rb+");
    if (fp == nullptr) {
        malloc_printf("[hawkeye] fail to open:%s, %s\n", path, strerror(errno));
        return nullptr;
    }

    size_t size = mtha_get_file_size(fileno(fp));
    if (size <= 0)
        return nullptr;

    void *ptr = mmap(nullptr, size, PROT_READ | PROT_WRITE, MAP_FILE | MAP_SHARED, fileno(fp), 0);
    if (ptr == MAP_FAILED) {
        malloc_printf("[hawkeye] fail to open:%s\n", strerror(errno));
        return nullptr;
    }

    mtha_splay_tree *tree = (mtha_splay_tree *)ptr;
    tree->mmap_fp = fp;
    tree->node = (mtha_splay_tree_node *)((char *)ptr + sizeof(mtha_splay_tree));
    return tree;
}

size_t mmap_size_of_splay_tree_node_count(FILE *fp, size_t node_count) {
    size_t size = (sizeof(mtha_splay_tree) + node_count * sizeof(mtha_splay_tree_node));
    if (size < getpagesize() || (size % getpagesize() != 0)) {
        size = (size / getpagesize() + 1) * getpagesize();
        if (ftruncate(fileno(fp), size) != 0) {
            malloc_printf("[hawkeye] fail to truncate:%s, size:%zu\n", strerror(errno), size);
        }
    }
    return size;
}

mtha_splay_tree *mtha_splay_tree_create_on_mmapfile(size_t entry_count, const char *path) {
    if (!mtha_is_file_exist(path)) {
        if (!mtha_create_file(path)) {
            return nullptr;
        }
    }

    FILE *fp = fopen(path, "wb+");
    if (fp == nullptr) {
        malloc_printf("[hawkeye] fail to open:%s, %s\n", path, strerror(errno));
        return nullptr;
    }

    size_t size = mmap_size_of_splay_tree_node_count(fp, entry_count);

    void *ptr = mmap(nullptr, size, PROT_READ | PROT_WRITE, MAP_FILE | MAP_SHARED, fileno(fp), 0);
    if (ptr == MAP_FAILED) {
        malloc_printf("[hawkeye] create splay tree, fail to mmap: %s\n", strerror(errno));
        return nullptr;
    }

    malloc_printf("[hawkeye] splay tree mmap to %s \n", path);

    mtha_splay_tree *tree = (mtha_splay_tree *)ptr;
    bzero(tree, size);
    tree->max_index = (uint32_t)entry_count;
    tree->mmap_fp = fp;
    tree->mmap_size = size;
    tree->node = (mtha_splay_tree_node *)((char *)ptr + sizeof(mtha_splay_tree));
    return tree;
}

mtha_splay_tree *mtha_expand_splay_tree(mtha_splay_tree *tree) {
    FILE *fp = tree->mmap_fp;
    size_t old_size = mmap_size_of_splay_tree_node_count(fp, tree->max_index);
    size_t new_node_count = tree->max_index * 2;
    size_t new_size = mmap_size_of_splay_tree_node_count(fp, new_node_count);

    malloc_printf("[hawkeye] will expand splay_tree, from:%y to: %y\n", old_size, new_size);

    if (new_node_count > 2097152) {
        malloc_printf("[hawkeye] node count: %d, out of limit (2^21), if really need, change mtha_splay_tree_node structure first.\n", new_node_count);
        return nullptr;
    }

    void *copy = (void *)mtha_malloc(old_size);
    memcpy(copy, tree, old_size);
    munmap(tree, old_size);

    // if extend size fail, rollback to old state.
    if (ftruncate(fileno(fp), new_size) != 0) {
        malloc_printf("[hawkeye] fail to truncate to mmap file size %y \n", new_size);
        mtha_free(copy);
        return nullptr;
    }

    fseek(fp, 0, SEEK_SET);

    void *new_mmapptr = mmap(nullptr, new_size, PROT_READ | PROT_WRITE, MAP_FILE | MAP_SHARED, fileno(fp), 0);
    if (new_mmapptr == nullptr || new_mmapptr == MAP_FAILED) {
        malloc_printf("[hawkeye] expand splay tree, fail to mmap: %s\n", strerror(errno));
        mtha_free(copy);
        return nullptr;
    }

    memset(new_mmapptr, '\0', new_size);
    memcpy(new_mmapptr, copy, old_size);

    mtha_free(copy);

    mtha_splay_tree *new_tree = (mtha_splay_tree *)new_mmapptr;
    new_tree->max_index = (uint32_t)new_node_count;
    new_tree->mmap_size = new_size;
    new_tree->node = (mtha_splay_tree_node *)((char *)new_mmapptr + sizeof(mtha_splay_tree));
    malloc_printf("[hawkeye] expand mmap file size: %y -> %y, node_count: %d\n", old_size, new_size, new_node_count);
    return new_tree;
}

mtha_splay_tree *mtha_splay_tree_create(size_t entry_count) {
    mtha_splay_tree *tree = (mtha_splay_tree *)mtha_malloc(sizeof(mtha_splay_tree));
    tree->max_index = (uint32_t)entry_count;
    tree->root_index = 0;
    tree->node_index = 0;
    tree->mmap_size = 0;
    tree->nextInsertIndex = 0;
    tree->node = (mtha_splay_tree_node *)mtha_malloc(entry_count * sizeof(mtha_splay_tree_node));
    return tree;
}

uint32_t mtha_splay_tree_relation(mtha_splay_tree_node *node, uint32_t nodeIndex) {
    return nodeIndex == node[node[nodeIndex].index.parent].index.right;
}

void mtha_splay_tree_rotate(mtha_splay_tree_node *node, uint32_t nodeIndex) {
    uint32_t parent = node[nodeIndex].index.parent;
    uint32_t grand = node[parent].index.parent;
    uint32_t cur = (nodeIndex == node[parent].index.right ? node[nodeIndex].index.left : node[nodeIndex].index.right);
    node[parent].index.parent = nodeIndex;
    node[nodeIndex].index.parent = grand;

    if (grand) {
        if (parent == node[grand].index.left) {
            node[grand].index.left = nodeIndex;
        } else {
            node[grand].index.right = nodeIndex;
        }
    }
    if (cur) {
        node[cur].index.parent = parent;
    }
    if (nodeIndex == node[parent].index.left) {
        node[nodeIndex].index.right = parent;
        node[parent].index.left = cur;
    } else {
        node[nodeIndex].index.left = parent;
        node[parent].index.right = cur;
    }
}

void mtha_splay_tree_splay(mtha_splay_tree *tree, uint32_t nodeIndex, uint32_t tmpIndex) {
    while (tree->node[nodeIndex].index.parent != tmpIndex) {
        if (tree->node[tree->node[nodeIndex].index.parent].index.parent != tmpIndex) {
            if (mtha_splay_tree_relation(tree->node, nodeIndex) == mtha_splay_tree_relation(tree->node, tree->node[nodeIndex].index.parent)) {
                mtha_splay_tree_rotate(tree->node, tree->node[nodeIndex].index.parent);
            } else {
                mtha_splay_tree_rotate(tree->node, nodeIndex);
            }
        }
        mtha_splay_tree_rotate(tree->node, nodeIndex);
    }
    if (!tmpIndex) {
        tree->root_index = nodeIndex;
    }
}

uint32_t mtha_splay_tree_search(mtha_splay_tree *tree, vm_address_t addr, bool splay) {
    if (!tree->root_index) {
        return 0;
    }
    uint32_t idx = tree->root_index;
    while (idx) {
        if (addr == tree->node[idx].addr_cnt.addr) {
            if (splay) {
                mtha_splay_tree_splay(tree, idx, 0);
            }
            return idx;
        } else if (addr < tree->node[idx].addr_cnt.addr) {
            idx = tree->node[idx].index.left;
        } else if (addr > tree->node[idx].addr_cnt.addr) {
            idx = tree->node[idx].index.right;
        }
    }
    return 0;
}

bool mtha_splay_tree_insert(mtha_splay_tree *tree, uint64_t addr, uint64_t stackid_and_flags, uint64_t category_and_size) {
    if (!tree->root_index) {
        tree->root_index = ++tree->node_index;
        tree->node[tree->root_index] = mtha_splay_node_init(addr, stackid_and_flags, category_and_size, 0);
        return true;
    }

    if (tree->node_index >= tree->max_index) {
        return false;
    }

    uint32_t idx = tree->root_index, parent = 0;
    while (idx && addr != tree->node[idx].addr_cnt.addr) {
        parent = idx;
        idx = (addr < tree->node[idx].addr_cnt.addr ? tree->node[idx].index.left : tree->node[idx].index.right);
    }

    if (idx) {
        tree->node[idx].addr_cnt.cnt++;
    } else {
        // 复用之前已经删除的内存空间
        if (tree->nextInsertIndex && tree->nextInsertIndex <= tree->node_index) {
            idx = tree->node[tree->nextInsertIndex].addr_cnt.cnt;
            tree->nextInsertIndex = tree->node[tree->nextInsertIndex].index.parent;
            tree->node[idx] = mtha_splay_node_init(addr, stackid_and_flags, category_and_size, parent);
        } else {
            idx = ++tree->node_index;
            tree->node[idx] = mtha_splay_node_init(addr, stackid_and_flags, category_and_size, parent);
        }
        if (tree->node[idx].addr_cnt.addr < tree->node[parent].addr_cnt.addr) {
            tree->node[parent].index.left = idx;
        } else {
            tree->node[parent].index.right = idx;
        }
    }

    // 插入后是否需要 Splay 操作
    mtha_splay_tree_splay(tree, idx, 0);
    tree->root_index = idx;
    return true;
}

mtha_splay_tree_node mtha_splay_tree_delete(mtha_splay_tree *tree, vm_address_t addr) {
    uint32_t idx = mtha_splay_tree_search(tree, addr, tree);
    if (!idx) {
        mtha_splay_tree_node empty_node = {
            .index.parent = 0,
            .index.right = 0,
            .index.left = 0,
            .index.extra = 0,
            .addr_cnt.addr = 0,
            .addr_cnt.cnt = 0,
            .category_and_size = 0,
            .stackid_and_flags = 0,
        };
        return empty_node;
    }

    mtha_splay_tree_node removedNode = tree->node[idx];

    mtha_splay_tree_splay(tree, idx, 0);

    if (tree->node[idx].addr_cnt.cnt > 1) {
        tree->node[idx].addr_cnt.cnt--;
        return removedNode;
    }
    if (!tree->node[idx].index.left || !tree->node[idx].index.right) {
        tree->root_index = tree->node[idx].index.left + tree->node[idx].index.right;
    } else {
        uint32_t temp = tree->node[idx].index.right;
        while (tree->node[temp].index.left) {
            temp = tree->node[temp].index.left;
        }
        mtha_splay_tree_splay(tree, temp, idx);
        tree->node[temp].index.left = tree->node[idx].index.left;
        tree->node[tree->node[temp].index.left].index.parent = temp;
        tree->root_index = temp;
    }
    tree->node[tree->root_index].index.parent = 0;
    tree->node[idx].addr_cnt.addr = 0;
    tree->node[idx].category_and_size = 0;
    tree->node[idx].addr_cnt.cnt = idx;
    tree->node[idx].index.parent = tree->nextInsertIndex;
    tree->nextInsertIndex = idx;

    return removedNode;
}

void mtha_splay_tree_close(mtha_splay_tree *tree) {
    FILE *fp = 0;
    if (tree != MAP_FAILED && tree != nullptr) {
        msync(tree, tree->mmap_size, MS_ASYNC);

        fp = tree->mmap_fp;
        munmap(tree, tree->mmap_size);
        tree = nullptr;
    }

    if (fp != nullptr) {
        fclose(fp);
        fp = nullptr;
    }
}

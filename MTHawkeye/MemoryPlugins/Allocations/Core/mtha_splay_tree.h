//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/7/10
// Created by: Huni
//


#ifndef mtha_splay_tree_h
#define mtha_splay_tree_h

#import <assert.h>
#import <mach/mach.h>
#import <malloc/malloc.h>
#import <stdbool.h>
#import <stdio.h>
#import <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

// MARK: - Macros
#define MTH_ALLOCATIONS_FLAGS_SHIFT 56
#define MTH_ALLOCATIONS_USER_TAG_SHIFT 24
#define MTH_ALLOCATIONS_FLAGS(longlongvar) (uint32_t)((uint64_t)(longlongvar) >> MTH_ALLOCATIONS_FLAGS_SHIFT)
#define MTH_ALLOCATIONS_VM_USER_TAG(flags) (((flags)&VM_FLAGS_ALIAS_MASK) >> MTH_ALLOCATIONS_USER_TAG_SHIFT)
#define MTH_ALLOCATIONS_FLAGS_AND_USER_TAG(longlongvar) \
    (uint32_t)(MTH_ALLOCATIONS_FLAGS(longlongvar) | (((uint64_t)(longlongvar)&0x00FF000000000000ull) >> MTH_ALLOCATIONS_USER_TAG_SHIFT))

#define MTH_ALLOCATIONS_OFFSET_MASK 0x0000FFFFFFFFFFFFull
#define MTH_ALLOCATIONS_OFFSET(longlongvar) ((longlongvar)&MTH_ALLOCATIONS_OFFSET_MASK)

#define MTH_ALLOCATIONS_OFFSET_AND_FLAGS(longlongvar, type_flags) \
    (((uint64_t)(longlongvar)&MTH_ALLOCATIONS_OFFSET_MASK) | ((uint64_t)(type_flags) << MTH_ALLOCATIONS_FLAGS_SHIFT) | (((uint64_t)(type_flags)&0xFF000000ull) << MTH_ALLOCATIONS_USER_TAG_SHIFT))

#define MTH_ALLOCATIONS_SIZE_SHIFT 36 // 移动环境下内存分配较小，可用 30bit 来保存单一对象的分配内存大小
#define MTH_ALLOCATIONS_SIZE(longlongvar) (uint32_t)((uint64_t)(longlongvar) >> MTH_ALLOCATIONS_SIZE_SHIFT)
#define MTH_ALLOCATIONS_CATEGORY_MASK 0x0000FFFFFFFFFull
#define MTH_ALLOCATIONS_CATEGORY(longlongvar) ((longlongvar)&MTH_ALLOCATIONS_CATEGORY_MASK)
#define MTH_ALLOCATIONS_CATEGORY_AND_SIZE(longlongvar, size) \
    (((uint64_t)(longlongvar)&MTH_ALLOCATIONS_CATEGORY_MASK) | ((uint64_t)(size) << MTH_ALLOCATIONS_SIZE_SHIFT))


/* Macro used to disguise addresses so that leak finding can work */
#define MTH_ALLOCATIONS_DISGUISE(address) ((address) ^ 0x00005555) /* nicely idempotent */

typedef struct _mtha_splay_tree_node {
    struct {
        uint32_t parent : 21; // max for 2097152 pointer.
        uint32_t left : 21;   //
        uint32_t right : 21;
        uint32_t extra : 1; // for other use
    } index;
    struct {
        uint64_t addr : 36;
        uint32_t cnt : 28;
    } addr_cnt;
    uint64_t category_and_size; // top 30 bits are the size.
    uint64_t stackid_and_flags; // top 8 bits are actually the flags!
} mtha_splay_tree_node;

typedef struct _mtha_splay_tree {
    uint32_t root_index;
    uint32_t node_index;
    uint32_t max_index;
    FILE *mmap_fp;
    size_t mmap_size;
    uint32_t nextInsertIndex;
    mtha_splay_tree_node *node;
} mtha_splay_tree;

mtha_splay_tree *mtha_splay_tree_read_from_mmapfile(const char *path);

mtha_splay_tree *mtha_splay_tree_create_on_mmapfile(size_t entry_count, const char *path);

mtha_splay_tree *mtha_expand_splay_tree(mtha_splay_tree *tree);

mtha_splay_tree *mtha_splay_tree_create(size_t entry_count);

bool mtha_splay_tree_insert(mtha_splay_tree *tree, uint64_t addr, uint64_t stackid_and_flags, uint64_t category_and_size);

uint32_t mtha_splay_tree_search(mtha_splay_tree *tree, vm_address_t addr, bool splay);

mtha_splay_tree_node mtha_splay_tree_delete(mtha_splay_tree *tree, vm_address_t addr);

void mtha_splay_tree_close(mtha_splay_tree *tree);


#ifdef __cplusplus
}
#endif

#endif /* mtha_splay_tree_h */

//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/7/27
// Created by: EuanC
//


#include <assert.h>
#include <errno.h>
#include <execinfo.h>
#include <limits.h>
#include <malloc/malloc.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#include "mtha_backtrace_uniquing_table.h"
#include "mtha_file_utils.h"
#include "mtha_inner_allocate.h"


// MARK: - In-Memory Backtrace Uniquing

static const uint64_t max_table_size_lite = UINT32_MAX;
//static const uint64_t max_table_size_normal = UINT64_MAX;

mtha_backtrace_uniquing_table *_mtha_create_uniquing_table_with_fd(FILE *fp, size_t size);

mtha_backtrace_uniquing_table *mtha_create_uniquing_table(const char *filepath, size_t default_page_size) {
    if (!mtha_is_file_exist(filepath)) {
        if (!mtha_create_file(filepath))
            return nullptr;
    }

    FILE *fp = fopen(filepath, "wb+");
    if (fp == nullptr) {
        malloc_printf("[hawkeye] fail to open:%s, %s", filepath, strerror(errno));
        return nullptr;
    }

    malloc_printf("[hawkeye] create uniquing table, mmap to %s \n", filepath);

    return _mtha_create_uniquing_table_with_fd(fp, default_page_size);
}

mtha_backtrace_uniquing_table *mtha_read_uniquing_table_from(const char *filepath) {
    if (!mtha_is_file_exist(filepath))
        return nullptr;

    FILE *fp = fopen(filepath, "rb+");
    if (fp == nullptr) {
        malloc_printf("[hawkeye] fail to open:%s, %s", filepath, strerror(errno));
        return nullptr;
    }

    size_t size = mtha_get_file_size(fileno(fp));
    if (size <= 0)
        return nullptr;

    void *ptr = mmap(nullptr, size, PROT_READ | PROT_WRITE, MAP_FILE | MAP_SHARED, fileno(fp), 0);
    if (ptr == MAP_FAILED)
        return nullptr;

    mtha_backtrace_uniquing_table *utable = (mtha_backtrace_uniquing_table *)ptr;
    utable->mmap_fp = fp;
    utable->u.table = (vm_address_t *)((char *)ptr + sizeof(mtha_backtrace_uniquing_table));
    utable->table_address = (uintptr_t)utable->u.table;
    return utable;
}

mtha_backtrace_uniquing_table *_mtha_create_uniquing_table_with_fd(FILE *fp, size_t numPages) {
    size_t tableSize = (size_t)numPages * vm_page_size;
    size_t fileSize = sizeof(mtha_backtrace_uniquing_table) + tableSize;

    if (fileSize < getpagesize() || (fileSize % getpagesize() != 0)) {
        fileSize = (fileSize / getpagesize() + 1) * getpagesize();
        if (ftruncate(fileno(fp), fileSize) != 0) {
            malloc_printf("[hawkeye] fail to truncate:%s, size:%zu", strerror(errno), fileSize);
        }
    }

    fseek(fp, 0, SEEK_SET);

    void *ptr = mmap(nullptr, fileSize, PROT_READ | PROT_WRITE, MAP_FILE | MAP_SHARED, fileno(fp), 0);
    if (ptr == MAP_FAILED || ptr == MAP_FAILED) {
        malloc_printf("[hawkeye] create uniquing_table, fail to mmap: %s\n", strerror(errno));
        return nullptr;
    }

    mtha_backtrace_uniquing_table *uniquing_table = (mtha_backtrace_uniquing_table *)ptr;
    bzero(uniquing_table, fileSize);
    uniquing_table->mmap_fp = fp;
    uniquing_table->fileSize = (uint32_t)fileSize;
    uniquing_table->numPages = (uint32_t)numPages;
    uniquing_table->tableSize = (uint32_t)(uniquing_table->numPages * vm_page_size);
    uniquing_table->numNodes = (uint32_t)(((uniquing_table->tableSize / (sizeof(vm_address_t))) >> 1) << 1); // make sure it's even.
    uniquing_table->u.table = (vm_address_t *)((char *)ptr + sizeof(mtha_backtrace_uniquing_table));
    uniquing_table->table_address = (uintptr_t)uniquing_table->u.table;
    uniquing_table->max_collide = MTHA_VM_INITIAL_MAX_COLLIDE;
    uniquing_table->untouchableNodes = 0;
    uniquing_table->max_table_size = max_table_size_lite;
    uniquing_table->in_client_process = 0;

#if MTH_ALLOCATIONS_DEBUG
    malloc_printf("[hawkeye] create_uniquing_table(): creating. page: %d*%d size: %lldKB == %lldMB, numnodes: %lld (%lld untouchable)\n",
        uniquing_table->numPages, vm_page_size, tableSize >> 10, tableSize >> 20, uniquing_table->numNodes,
        uniquing_table->untouchableNodes);
    malloc_printf("[hawkeye] create_uniquing_table(): table: %p; end: %p\n", uniquing_table->u.table,
        (void *)((uintptr_t)uniquing_table->u.table + (uintptr_t)tableSize));
#endif
    return uniquing_table;
}

void mtha_destroy_uniquing_table(mtha_backtrace_uniquing_table *table) {
    FILE *fp = 0;
    if (table != MAP_FAILED && table != nullptr) {
        fp = table->mmap_fp;
        munmap(table, table->fileSize);
        table = nullptr;
    }

    if (fp != nullptr) {
        fclose(fp);
        fp = nullptr;
    }
}

mtha_backtrace_uniquing_table *mtha_expand_uniquing_table(mtha_backtrace_uniquing_table *old_uniquing_table) {
    malloc_printf("[hawkeye] will expand uniquing table.\n");
    assert(!old_uniquing_table->in_client_process);

    FILE *fp = old_uniquing_table->mmap_fp;

    uint32_t newNumPages = old_uniquing_table->numPages << MTHA_VM_EXPAND_FACTOR;
    if (newNumPages * vm_page_size > old_uniquing_table->max_table_size) {
        malloc_printf("[hawkeye][error] no more space in uniquing table\n");
        return nullptr;
    }

    uint32_t oldTableSize = old_uniquing_table->tableSize;
    uint32_t maxCollide = old_uniquing_table->max_collide + MTHA_VM_COLLISION_GROWTH_RATE;
    uint32_t untouchableNodes = old_uniquing_table->numNodes;

    malloc_zone_t *zone = malloc_create_zone(0, 0);
    malloc_set_zone_name(zone, "backtrace_uniquing_table_tmp_zone");

#if MTH_ALLOCATIONS_DEBUG
    malloc_printf(
        "[hawkeye] expandUniquingTable(): expanded from nodes full: %lld of: %lld (~%2d%%); to nodes: %lld (inactive = %lld); unique "
        "bts: %lld\n",
        old_uniquing_table->nodesFull, old_uniquing_table->numNodes, (int)(((old_uniquing_table->nodesFull * 100.0) / (double)old_uniquing_table->numNodes) + 0.5),
        old_uniquing_table->numNodes, old_uniquing_table->untouchableNodes, old_uniquing_table->backtracesContained);
    malloc_printf("[hawkeye] expandUniquingTable(): deallocate: %p; end: %p\n", oldTableSize, (void *)((uintptr_t)old_uniquing_table->u.table + (uintptr_t)oldTableSize));
#endif

    void *copy = (void *)zone->malloc(zone, oldTableSize);
    memcpy(copy, old_uniquing_table->u.table, oldTableSize);
    munmap(old_uniquing_table, old_uniquing_table->fileSize);

    mtha_backtrace_uniquing_table *tmp_uniquing_table = _mtha_create_uniquing_table_with_fd(fp, newNumPages);

    memcpy(tmp_uniquing_table->u.table, copy, oldTableSize);

    zone->free(zone, copy);
    copy = nullptr;
    malloc_destroy_zone(zone);
    zone = nullptr;

    if (tmp_uniquing_table == nullptr) {
        return nullptr;
    }

    tmp_uniquing_table->max_collide = maxCollide;
    tmp_uniquing_table->untouchableNodes = untouchableNodes;

#if MTH_ALLOCATIONS_DEBUG
    malloc_printf("[hawkeye] expandUniquingTable(): allocate: %p; end: %p\n", tmp_uniquing_table->u.table,
        (void *)((uintptr_t)tmp_uniquing_table->u.table + (uintptr_t)(tmp_uniquing_table->fileSize)));
    malloc_printf("[hawkeye] expandUniquingTable(): new size = %llu, %lldKB == %lldMB\n", tmp_uniquing_table->tableSize, tmp_uniquing_table->tableSize >> 10, tmp_uniquing_table->tableSize >> 20);
#endif

    return tmp_uniquing_table;
}

void mtha_add_new_slot(mtha_table_slot_t *mtha_table_slot, vm_address_t address, mtha_table_slot_index parent) {
    mtha_table_slot_t new_slot;
    new_slot.normal_slot.address = address;
    new_slot.normal_slot.parent = parent;
    *mtha_table_slot = new_slot;
}

int mtha_enter_frames_in_table(mtha_backtrace_uniquing_table *uniquing_table, uint64_t *foundIndex, vm_address_t *frames, int32_t count) {
    assert(!uniquing_table->in_client_process);

    // The hash values need to be the same size as the addresses (because we use the value -1), for clarity, define a new type
    typedef vm_address_t hash_index_t;

    hash_index_t uParent = mtha_slot_no_parent_normal;
    hash_index_t modulus = (uniquing_table->numNodes - uniquing_table->untouchableNodes - 1);

    int32_t lcopy = count;
    int32_t returnVal = 1;
    hash_index_t hash_multiplier = ((uniquing_table->numNodes - uniquing_table->untouchableNodes) / (uniquing_table->max_collide * 2 + 1));

#if MTH_ALLOCATIONS_DEBUG
    static int32_t total_frame_count = 0;
    static int32_t enter_count = 0;
    static int32_t new_slots_count = 0;
    static int32_t enter_count_unique = 0;

    bool unique_stacks = true;
    total_frame_count += count;
    enter_count += 1;
#endif


    while (--lcopy >= 0) {
        vm_address_t thisPC = frames[lcopy];
        hash_index_t hash = uniquing_table->untouchableNodes + (((uParent << 4) ^ (thisPC >> 2)) % modulus);
        int32_t collisions = uniquing_table->max_collide;

        while (collisions--) {
            mtha_table_slot_t *mtha_table_slot = (mtha_table_slot_t *)(uniquing_table->u.table + hash);

            if (mtha_table_slot->slots.slot0 == 0 && mtha_table_slot->slots.slot1 == 0) {
                mtha_add_new_slot(mtha_table_slot, thisPC, (mtha_table_slot_index)uParent);

#if MTH_ALLOCATIONS_DEBUG
                unique_stacks = false;
                new_slots_count++;
#endif
                uParent = hash;
                break;
            }

            mtha_slot_address address = (mtha_slot_address)mtha_table_slot->normal_slot.address;
            mtha_slot_parent parent = mtha_table_slot->normal_slot.parent;

            if (address == thisPC && parent == uParent) {
                uParent = hash;
                break;
            }

            hash += collisions * hash_multiplier + 1;

            if (hash >= uniquing_table->numNodes) {
                hash -= (uniquing_table->numNodes - uniquing_table->untouchableNodes); // wrap around.
            }
        }

        if (collisions < 0) {
            returnVal = 0;
            break;
        }
    }

    if (returnVal) {
        *foundIndex = uParent;
    }

#if MTH_ALLOCATIONS_DEBUG
    if (unique_stacks) enter_count_unique++;

    if (enter_count % 250000 == 0) {
        malloc_printf("[hawkeye] enter:%u, enter_u:%u, frames:%u, new_slots:%u\n", enter_count, enter_count_unique, total_frame_count, new_slots_count);
    }
#endif

    return returnVal;
}

// MARK: -
vm_address_t *mtha_get_node_from_uniquing_table(mtha_backtrace_uniquing_table *uniquing_table, uint64_t index_pos) {
    //    assert(uniquing_table->in_client_process);
    // 原始代码，跨进程读取，借助了 table_chunk_header_t 结构
    if (uniquing_table->in_client_process) {
        mtha_table_chunk_header_t *table_chunk_hdr = uniquing_table->u.first_table_chunk_hdr;
        uint64_t start_node_of_chunk = 0;
        while (table_chunk_hdr && index_pos > start_node_of_chunk + table_chunk_hdr->num_nodes_in_chunk) {
            table_chunk_hdr = table_chunk_hdr->next_table_chunk_header;
            if (table_chunk_hdr) {
                start_node_of_chunk += table_chunk_hdr->num_nodes_in_chunk;
            }
        }

        // Handle case where someone passes an invalid stack id
        // <rdar://problem/25337823> get_node_from_uniquing_table should be more tolerant
        if (!table_chunk_hdr) {
            return NULL;
        }

        uint64_t index_in_chunk = index_pos - start_node_of_chunk;

        vm_address_t *node = table_chunk_hdr->table_chunk + index_in_chunk;
        return node;
    } else {
        vm_address_t *node = (vm_address_t *)uniquing_table->table_address + index_pos;
        return node;
    }
}

void mtha_unwind_stack_from_table_index(mtha_backtrace_uniquing_table *uniquing_table,
    uint64_t index_pos,
    vm_address_t *out_frames_buffer,
    uint32_t *out_frames_count,
    uint32_t max_frames) {
    vm_address_t *node = mtha_get_node_from_uniquing_table(uniquing_table, index_pos);
    uint32_t foundFrames = 0;
    mtha_slot_parent end_parent = mtha_slot_no_parent_normal;

    if (node && index_pos < uniquing_table->numNodes) {
        while (foundFrames < max_frames) {
            mtha_table_slot_t *table_slot = (mtha_table_slot_t *)(node);
            mtha_slot_address address = (mtha_slot_address)table_slot->normal_slot.address;

            out_frames_buffer[foundFrames++] = address;

            mtha_slot_parent parent = table_slot->normal_slot.parent;

            if (parent == end_parent) {
                break;
            }

            node = mtha_get_node_from_uniquing_table(uniquing_table, parent);
        }
    }

    *out_frames_count = foundFrames;
}

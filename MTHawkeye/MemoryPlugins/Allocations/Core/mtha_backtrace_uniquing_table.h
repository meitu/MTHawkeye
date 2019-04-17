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


#ifndef mtha_backtrace_uniquing_table_h
#define mtha_backtrace_uniquing_table_h

#include <mach/mach.h>
#include <stdbool.h>
#include <stdio.h>

#define MTH_ALLOCATIONS_DEBUG 0


#ifdef __cplusplus
extern "C" {
#endif


// The expansion factor controls the shifting up of table size. A factor of 1 will double the size upon expanding,
// 2 will quadruple the size, etc. Maintaining a 66% fill in an ideal table requires the collision allowance to
// increase by 3 for every quadrupling of the table size (although this the constant applied to insertion
// performance O(c*n))
#define MTHA_VM_EXPAND_FACTOR 1
#define MTHA_VM_COLLISION_GROWTH_RATE 3

// For a uniquing table, the useful node size is slots := floor(table_byte_size / (2 * sizeof(vm_address_t)))
// Some useful numbers for the initial max collision value (desiring 66% fill):
// 16K-23K slots -> 16 collisions
// 24K-31K slots -> 17 collisions
// 32K-47K slots -> 18 collisions
// 48K-79K slots -> 19 collisions
// 80K-96K slots -> 20 collisions
#define MTHA_VM_INITIAL_MAX_COLLIDE 20
#define MTHA_VM_DEFAULT_UNIQUING_PAGE_SIZE_WITH_SYS 1024   // memory cost: pages * vm_page_size(16386); default: 16MB
#define MTHA_VM_DEFAULT_UNIQUING_PAGE_SIZE_WITHOUT_SYS 256 // memory cost: pages * vm_page_size(16386); default: 4MB


const uint64_t mtha_vm_invalid_stack_id = (uint64_t)(-1ll);


// backtrace uniquing table chunks used in client-side stack log reading code,
// in case we can't read the whole table in one mach_vm_read() call.
typedef struct _mtha_table_chunk_header {
    uint64_t num_nodes_in_chunk;
    uint64_t table_chunk_size;
    vm_address_t *table_chunk;
    struct _mtha_table_chunk_header *next_table_chunk_header;
} mtha_table_chunk_header_t;

#pragma pack(push, 4)
typedef struct _mtha_backtrace_uniquing_table {
    FILE *mmap_fp;     // mmap file descriptor
    uint32_t fileSize; // mmap file size
    uint32_t numPages; // number of pages of the table
    uint32_t numNodes;
    uint32_t tableSize;
    uint32_t untouchableNodes;
    vm_address_t table_address;
    int32_t max_collide;
    // 'table_address' is just an always 64-bit version of the pointer-sized 'table' field to remotely read;
    // it's important that the offset of 'table_address' in the struct does not change between 32 and 64-bit.
#if MTH_ALLOCATIONS_DEBUG
    uint64_t nodesFull;
    uint64_t backtracesContained;
#endif
    uint64_t max_table_size;
    bool in_client_process : 1;
    union {
        vm_address_t *table;                              // in "target" process;  allocated using vm_allocate()
        mtha_table_chunk_header_t *first_table_chunk_hdr; // in analysis process
    } u;
} mtha_backtrace_uniquing_table;
#pragma pack(pop)


typedef vm_address_t mtha_slot_address;
typedef uint32_t mtha_slot_parent;
typedef uint32_t mtha_table_slot_index;

#pragma pack(push, 4)
typedef struct {
    union {
        struct {
            uint32_t slot0;
            uint32_t slot1;
        } slots;

        struct {
            uint64_t address : 36;
            uint32_t parent : 28;
        } normal_slot;
    };
} mtha_table_slot_t;
#pragma pack(pop)

_Static_assert(sizeof(mtha_table_slot_t) == 8, "table_slot_t must be 64 bits");

const mtha_slot_parent mtha_slot_no_parent_normal = 0xFFFFFFF; // 28 bits

mtha_backtrace_uniquing_table *mtha_create_uniquing_table(const char *filepath, size_t default_page_size);

mtha_backtrace_uniquing_table *mtha_read_uniquing_table_from(const char *filepath);

void mtha_destroy_uniquing_table(mtha_backtrace_uniquing_table *table);

mtha_backtrace_uniquing_table *mtha_expand_uniquing_table(mtha_backtrace_uniquing_table *old_uniquing_table);

int mtha_enter_frames_in_table(mtha_backtrace_uniquing_table *uniquing_table, uint64_t *foundIndex, vm_address_t *frames, int32_t count);

void mtha_add_new_slot(mtha_table_slot_t *table_slot, vm_address_t address, mtha_table_slot_index parent);

void mtha_unwind_stack_from_table_index(mtha_backtrace_uniquing_table *uniquing_table,
    uint64_t index_pos,
    vm_address_t *out_frames_buffer,
    uint32_t *out_frames_count,
    uint32_t max_frames);

#ifdef __cplusplus
}
#endif

#endif /* mtha_backtrace_uniquing_table_h */

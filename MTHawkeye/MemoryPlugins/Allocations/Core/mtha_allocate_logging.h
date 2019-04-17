//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/7/25
// Created by: EuanC
//


#ifndef mtha_memory_allocate_logging_h
#define mtha_memory_allocate_logging_h

#include <mach/mach.h>
#include <stdbool.h>
#include <stdio.h>
#include <sys/syslimits.h>

#include "mtha_backtrace_uniquing_table.h"
#include "mtha_splay_tree.h"


#define MTH_ALLOCATIONS_MAX_STACK_SIZE 200

#define mth_allocations_type_free 0
#define mth_allocations_type_generic 1        /* anything that is not allocation/deallocation */
#define mth_allocations_type_alloc 2          /* malloc, realloc, etc... */
#define mth_allocations_type_dealloc 4        /* free, realloc, etc... */
#define mth_allocations_type_vm_allocate 16   /* vm_allocate or mmap */
#define mth_allocations_type_vm_deallocate 32 /* vm_deallocate or munmap */
#define mth_allocations_type_mapped_file_or_shared_mem 128


// The valid flags include those from VM_FLAGS_ALIAS_MASK, which give the user_tag of allocated VM regions.
#define mth_allocations_valid_type_flags ( \
    mth_allocations_type_generic | mth_allocations_type_alloc | mth_allocations_type_dealloc | mth_allocations_type_vm_allocate | mth_allocations_type_vm_deallocate | mth_allocations_type_mapped_file_or_shared_mem | VM_FLAGS_ALIAS_MASK);


// Following flags are absorbed by stack_logging_log_stack()
#define mth_allocations_flag_zone 8     /* NSZoneMalloc, etc... */
#define mth_allocations_flag_cleared 64 /* for NewEmptyHandle */


#ifdef __cplusplus
extern "C" {
#endif


// MARK: - Record files info
extern char mtha_records_cache_dir[PATH_MAX];    /**< the directory to cache all the records, should be set before start. */
extern const char *mtha_malloc_records_filename; /**< the heap records filename */
extern const char *mtha_vm_records_filename;     /**< the vm records filename */
extern const char *mtha_stacks_records_filename; /**< the backtrace records filename */


// MARK: - Allocations Logging

extern boolean_t mtha_memory_allocate_logging_enabled; /* when clear, no logging takes place */

extern boolean_t mth_allocations_need_sys_frame;        /**< record system libraries frames when record backtrace, default false*/
extern uint32_t mth_allocations_stack_record_max_depth; /**< stack record max depth, default 50 */

// for storing/looking up allocations that haven't yet be written to disk; consistent size across 32/64-bit processes.
// It's important that these fields don't change alignment due to the architecture because they may be accessed from an
// analyzing process with a different arch - hence the pragmas.
#pragma pack(push, 4)
typedef struct {
    mtha_splay_tree *malloc_records = NULL;                  /**< store Heap memory allocations info, each item contains ptr,size,stackid */
    mtha_splay_tree *vm_records = NULL;                      /**< store other vm memory allocations info, each item contains ptr,size,stackid */
    mtha_backtrace_uniquing_table *backtrace_records = NULL; /**< store the stacks when allocate memory */
} mth_allocations_record_raw;
#pragma pack(pop)

extern mth_allocations_record_raw *mtha_recording; /**< single-thread access variables */

boolean_t mtha_prepare_memory_allocate_logging(void); /**< prepare logging before start */

/*
 when operating `mtha_recording`, you should make sure it's thread safe.
 use locking method below to keep it safe.
 */
void mtha_memory_allocate_logging_lock(void);
void mtha_memory_allocate_logging_unlock(void);


typedef void(mtha_malloc_logger_t)(uint32_t type_flags, uintptr_t zone_ptr, uintptr_t arg2, uintptr_t arg3, uintptr_t return_val, uint32_t num_hot_to_skip);

extern mtha_malloc_logger_t *malloc_logger;
extern mtha_malloc_logger_t *__syscall_logger;

void mtha_allocate_logging(uint32_t type_flags, uintptr_t zone_ptr, uintptr_t size, uintptr_t ptr_arg, uintptr_t return_val, uint32_t num_hot_to_skip);

// MARK: - Single chunk malloc detect
typedef void (^mtha_chunk_malloc_block)(size_t bytes, vm_address_t *stack_frames, size_t frames_count);
void mtha_start_single_chunk_malloc_detector(size_t threshold_in_bytes, mtha_chunk_malloc_block callback);
void mtha_config_single_chunk_malloc_threshold(size_t threshold_in_bytes);
void mtha_stop_single_chunk_malloc_detector(void);


#ifdef __cplusplus
}
#endif

#endif /* mtha_memory_allocate_logging_h */

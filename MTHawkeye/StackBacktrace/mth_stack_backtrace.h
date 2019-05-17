//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/4
// Created by: EuanC
//


#ifndef mth_stack_backtrace_h
#define mth_stack_backtrace_h

#include <mach/mach.h>
#include <stdio.h>

#define MTHawkeyeStackBacktracePerformanceTestEnabled 0

#ifdef MTHawkeyeStackBacktracePerformanceTestEnabled
#define _InternalMTHStackBacktracePerformanceTestEnabled MTHawkeyeStackBacktracePerformanceTestEnabled
#else
#define _InternalMTHStackBacktracePerformanceTestEnabled NO
#endif


#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uintptr_t *frames;
    size_t frames_size;
} mth_stack_backtrace;

mth_stack_backtrace *mth_malloc_stack_backtrace(void);
void mth_free_stack_backtrace(mth_stack_backtrace *stack_backtrace);

bool mth_stack_backtrace_of_thread(thread_t thread, mth_stack_backtrace *stack_backtrace, const size_t backtrace_depth_max, uintptr_t top_frames_to_skip);

#ifdef __cplusplus
}
#endif

#endif /* mth_stack_backtrace_h */

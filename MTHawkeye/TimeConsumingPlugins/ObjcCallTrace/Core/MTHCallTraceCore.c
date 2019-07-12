//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 01/11/2017
// Created by: EuanC
// Base on http://www.jianshu.com/p/c58001ae3da5 by Daiming
//


#include "MTHCallTraceCore.h"

#ifdef __aarch64__

// MARK: __aarch64__

#include <dispatch/dispatch.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <pthread.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>

#include <fishhook/fishhook.h>

static bool _call_record_enabled = false;
static bool _trace_all = false;
static uint32_t _record_time_threshold = 15 * 1000; // us
static int _max_call_depth = 5;
static pthread_key_t _thread_key;

__unused static id (*orig_objc_msgSend)(id, SEL, ...);

static mth_call_record *_callrecords;
static int _callrecordNum;
static int _recordAlloc;

typedef struct {
    id self;       // 通过 object_getClass 能够得到 Class 再通过 NSStringFromClass 能够得到类名
    Class cls;     // class
    SEL cmd;       // 通过 NSStringFromSelector 方法能够得到方法名
    uint64_t time; // us
    uintptr_t lr;  // link register
} thread_call_record;

typedef struct {
    thread_call_record *stack;
    int allocated_length;
    int index;
    bool is_main_thread;
} thread_call_stack;

static inline thread_call_stack *get_thread_call_stack() {
    thread_call_stack *cs = (thread_call_stack *)pthread_getspecific(_thread_key);
    if (cs == NULL) {
        cs = (thread_call_stack *)malloc(sizeof(thread_call_stack));
        cs->stack = (thread_call_record *)calloc(128, sizeof(thread_call_record));
        cs->allocated_length = 64;
        cs->index = -1;
        cs->is_main_thread = pthread_main_np();
        pthread_setspecific(_thread_key, cs);
    }
    return cs;
}

static void release_thread_call_stack(void *ptr) {
    thread_call_stack *cs = (thread_call_stack *)ptr;
    if (!cs) return;
    if (cs->stack) free(cs->stack);
    free(cs);
}

static inline void push_call_record(id _self, Class _cls, SEL _cmd, uintptr_t lr) {
    thread_call_stack *cs = get_thread_call_stack();
    if (cs) {
#if _InternalMTCallTracePerformanceTestEnabled
        mach_timebase_info_data_t timeinfo_;
        mach_timebase_info(&timeinfo_);

        uint64_t t0 = mach_absolute_time() * timeinfo_.numer / timeinfo_.denom;

        static double pre_cost_sum = 0;
        static int pre_cost_sum_counter = 0;
#endif

        int nextIndex = (++cs->index);
        if (nextIndex >= cs->allocated_length) {
            cs->allocated_length += 64;
            cs->stack = (thread_call_record *)realloc(cs->stack, cs->allocated_length * sizeof(thread_call_record));
        }
        thread_call_record *newRecord = &cs->stack[nextIndex];
        newRecord->self = _self;
        newRecord->cls = _cls;
        newRecord->cmd = _cmd;
        newRecord->lr = lr;

        if (cs->is_main_thread && _call_record_enabled) {
            struct timeval now;
            gettimeofday(&now, NULL);
            newRecord->time = now.tv_sec * 1000000 + now.tv_usec;
        }


#if _InternalMTCallTracePerformanceTestEnabled
        uint64_t t1 = mach_absolute_time() * timeinfo_.numer / timeinfo_.denom;

        double elapsed = (t1 - t0) / 1000.f;

        pre_cost_sum += elapsed;
        pre_cost_sum_counter++;
        if (pre_cost_sum_counter > 1000000) {
            printf("[hawkeye][profile] objc_msgSend_prev_call 1000000 time, cost %.3f ms\n", pre_cost_sum / 1000.f);
            pre_cost_sum = 0;
            pre_cost_sum_counter = 0;
        }
#endif

    } else {
    }
}

static inline uintptr_t pop_call_record() {
    thread_call_stack *cs = get_thread_call_stack();
    int curIndex = cs->index;
    int nextIndex = cs->index--;
    thread_call_record *pRecord = &cs->stack[nextIndex];
    if (cs->is_main_thread && _call_record_enabled) {

#if _InternalMTCallTracePerformanceTestEnabled
        mach_timebase_info_data_t timeinfo_;
        mach_timebase_info(&timeinfo_);

        uint64_t t0 = mach_absolute_time() * timeinfo_.numer / timeinfo_.denom;

        static double post_cost_sum = 0;
        static int post_cost_sum_counter = 0;
#endif

        struct timeval now;
        gettimeofday(&now, NULL);
        uint64_t time = now.tv_sec * 1000000 + now.tv_usec;
        uint32_t cost = (uint32_t)(time - pRecord->time);
        if (_trace_all || (cost > _record_time_threshold && cs->index < _max_call_depth)) {
            if (!_callrecords) {
                _recordAlloc = 1024;
                _callrecords = malloc(sizeof(mth_call_record) * _recordAlloc);
            }
            _callrecordNum++;
            if (_callrecordNum >= _recordAlloc) {
                _recordAlloc += 1024;
                _callrecords = realloc(_callrecords, sizeof(mth_call_record) * _recordAlloc);
            }
            mth_call_record *log = &_callrecords[_callrecordNum - 1];
            log->cls = pRecord->cls;
            log->depth = curIndex;
            log->sel = pRecord->cmd;
            log->cost = cost;

            log->event_time = pRecord->time * 1e-6;
        }

#if _InternalMTCallTracePerformanceTestEnabled
        uint64_t t1 = mach_absolute_time() * timeinfo_.numer / timeinfo_.denom;

        double elapsed = (t1 - t0) / 1000.f;

        post_cost_sum += elapsed;
        post_cost_sum_counter++;
        if (post_cost_sum_counter > 1000000) {
            printf("[hawkeye][profile] objc_msgSend_post_call 1000000 time, cost %.3f ms\n", post_cost_sum / 1000.f);
            post_cost_sum = 0;
            post_cost_sum_counter = 0;
        }
#endif
    }
    return pRecord->lr;
}

void before_objc_msgSend(id self, SEL _cmd, uintptr_t lr) {
    push_call_record(self, object_getClass(self), _cmd, lr);
}

uintptr_t after_objc_msgSend() {
    return pop_call_record();
}

// MARK: replacement objc_msgSend (arm64)
//replacement objc_msgSend (arm64)
// https://blog.nelhage.com/2010/10/amd64-and-va_arg/
// http://infocenter.arm.com/help/topic/com.arm.doc.ihi0055b/IHI0055B_aapcs64.pdf
// https://developer.apple.com/library/ios/documentation/Xcode/Conceptual/iPhoneOSABIReference/Articles/ARM64FunctionCallingConventions.html
#define call(b, value)                            \
    __asm volatile("stp x8, x9, [sp, #-16]!\n");  \
    __asm volatile("mov x12, %0\n" ::"r"(value)); \
    __asm volatile("ldp x8, x9, [sp], #16\n");    \
    __asm volatile(#b " x12\n");

#define save()                      \
    __asm volatile(                 \
        "stp x8, x9, [sp, #-16]!\n" \
        "stp x6, x7, [sp, #-16]!\n" \
        "stp x4, x5, [sp, #-16]!\n" \
        "stp x2, x3, [sp, #-16]!\n" \
        "stp x0, x1, [sp, #-16]!\n" \
                                    \
        "stp q8, q9, [sp, #-32]!\n" \
        "stp q6, q7, [sp, #-32]!\n" \
        "stp q4, q5, [sp, #-32]!\n" \
        "stp q2, q3, [sp, #-32]!\n" \
        "stp q0, q1, [sp, #-32]!\n");

#define load()                    \
    __asm volatile(               \
        "ldp q0, q1, [sp], #32\n" \
        "ldp q2, q3, [sp], #32\n" \
        "ldp q4, q5, [sp], #32\n" \
        "ldp q6, q7, [sp], #32\n" \
        "ldp q8, q9, [sp], #32\n" \
                                  \
        "ldp x0, x1, [sp], #16\n" \
        "ldp x2, x3, [sp], #16\n" \
        "ldp x4, x5, [sp], #16\n" \
        "ldp x6, x7, [sp], #16\n" \
        "ldp x8, x9, [sp], #16\n");

#define link(b, value)                           \
    __asm volatile("stp x8, lr, [sp, #-16]!\n"); \
    __asm volatile("sub sp, sp, #16\n");         \
    call(b, value);                              \
    __asm volatile("add sp, sp, #16\n");         \
    __asm volatile("ldp x8, lr, [sp], #16\n");

#define ret() __asm volatile("ret\n");

#define store_registers() \
    __asm volatile("stp x29, x30, [sp, #-0x10]\n");

#define setup_fp_sp()                         \
    __asm volatile("str x0, [sp, #-0x20]\n"); \
    __asm volatile("mov x0, sp\n"             \
                   "sub x0, fp, x0\n");       \
    __asm volatile(                           \
        "mov fp, sp\n"                        \
        "sub fp, fp, #0x10\n"                 \
        "sub sp, fp, x0\n");                  \
    __asm volatile("ldr x0, [fp, #-0x10]\n");

#define mark_frame_layout()                 \
    __asm volatile(".cfi_def_cfa w29, 16\n" \
                   ".cfi_offset w30, -8\n"  \
                   ".cfi_offset w29, -16\n");

#define copy_stack_content()              \
    __asm volatile("add x2, sp, #240\n"   \
                   "sub x2, fp, x2\n");   \
    __asm volatile("mov x3, #0x0\n"       \
                   "add x7, fp, #0x10\n"  \
                   "add x4, sp, #240\n"); \
    __asm volatile("cmp x3, x2\n"         \
                   "b.eq #24\n");         \
    __asm volatile("ldr x5, [x7, x3]\n"   \
                   "str x5, [x4, x3]\n"   \
                   "add x3, x3, #0x8\n"   \
                   "cmp x3, x2\n"         \
                   "b.lt #-16\n");

#define restore_fp_sp()                  \
    __asm volatile("mov sp, fp\n"        \
                   "add sp, sp, #0x10\n" \
                   "ldr fp, [fp]\n");

__attribute__((__naked__)) static void hook_Objc_msgSend() {
    // 1. store fp, lr value at top of the stack
    store_registers()

        //2. setup new fp & sp
        setup_fp_sp()

        //4. declare where we store our fp & lr, so that lldb can generate call stack.
        //https://stackoverflow.com/questions/7534420/gas-explanation-of-cfi-def-cfa-offset
        mark_frame_layout()

        //5. Save parameters. (Save register values)
        save()

        //6. copy the original stack frame
        copy_stack_content()

        // 7. call before msgSend & msgSend & after msgSend
        __asm volatile("mov x2, lr\n");

    // Call our before_objc_msgSend.
    call(blr, &before_objc_msgSend)

        // Load parameters.
        load()

        // Call through to the original objc_msgSend.
        call(blr, orig_objc_msgSend)

        // Save original objc_msgSend return value.
        save()

        // Call our after_objc_msgSend.
        call(blr, &after_objc_msgSend)

        //9. restore lr register, returned from after msgSend
        __asm volatile("mov lr, x0\n");

    //10. Load original objc_msgSend return value.
    load()

        //11. restore
        restore_fp_sp()

        //12. return
        ret()
}

// MARK: public method

void mth_calltraceStart(void) {

    _call_record_enabled = true;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pthread_key_create(&_thread_key, &release_thread_call_stack);
        rebind_symbols((struct rebinding[6]){
                           {"objc_msgSend", (void *)hook_Objc_msgSend, (void **)&orig_objc_msgSend},
                       },
            1);
    });
}

void mth_calltraceStop(void) {
    _call_record_enabled = false;
}

bool mth_calltraceRunning(void) {
    return _call_record_enabled;
}

void mth_calltraceConfigTimeThreshold(uint32_t us) {
    _record_time_threshold = us;
}

void mth_calltraceConfigMaxDepth(int depth) {
    _max_call_depth = depth;
}

void mth_calltraceTraceAll(void) {
    _trace_all = true;
}

void mth_calltraceTraceByThreshold(void) {
    _trace_all = false;
}

uint32_t mth_calltraceTimeThreshold(void) {
    return _record_time_threshold;
}

int mth_calltraceMaxDepth(void) {
    return _max_call_depth;
}

mth_call_record *mth_getCallRecords(int *num) {
    if (num) {
        *num = _callrecordNum;
    }
    return _callrecords;
}

void mth_clearCallRecords(void) {
    if (_callrecords) {
        free(_callrecords);
        _callrecords = NULL;
    }
    _callrecordNum = 0;
}

#else
// MARK: !__aarch64__

void mth_calltraceStart(void) {}
void mth_calltraceStop(void) {}
bool mth_calltraceRunning(void) {
    return false;
}

void mth_calltraceDisableTemp() {}
void mth_calltraceEnableTemp() {}

void mth_calltraceConfigTimeThreshold(uint32_t us) {}
void mth_calltraceConfigMaxDepth(int depth) {}
void mth_calltraceTraceAll(void) {}
void mth_calltraceTraceByThreshold(void) {}

uint32_t mth_calltraceTimeThreshold(void) {
    return 0;
}
int mth_calltraceMaxDepth(void) {
    return 0;
}

mth_call_record *mth_getCallRecords(int *num) {
    if (num) {
        *num = 0;
    }
    return NULL;
}

void mth_clearCallRecords(void) {}

#endif

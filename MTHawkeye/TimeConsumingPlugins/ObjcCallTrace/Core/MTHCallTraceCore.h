//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 01/11/2017
// Created by: EuanC
//


#ifndef MTHCallTraceCore_h
#define MTHCallTraceCore_h

#include <objc/objc.h>
#include <stdint.h>
#include <stdio.h>

#define MTHawkeyeCallTracePerformanceTestEnabled 0

#ifdef MTHawkeyeCallTracePerformanceTestEnabled
#define _InternalMTCallTracePerformanceTestEnabled MTHawkeyeCallTracePerformanceTestEnabled
#else
#define _InternalMTCallTracePerformanceTestEnabled NO
#endif

typedef struct {
    __unsafe_unretained Class cls;
    SEL sel;
    uint32_t cost; // us (1/1000 ms), max 4290s.
    uint32_t depth;
    double event_time; // unix time
} mth_call_record;

extern void mth_calltraceStart(void);
extern void mth_calltraceStop(void);
extern bool mth_calltraceRunning(void);

extern void mth_calltraceConfigTimeThreshold(uint32_t us); // default 15 * 1000
extern void mth_calltraceConfigMaxDepth(int depth);        // default 5

extern void mth_calltraceTraceAll(void);
extern void mth_calltraceTraceByThreshold(void);

extern uint32_t mth_calltraceTimeThreshold(void); // in us, max 4290 * 1e6 us.
extern int mth_calltraceMaxDepth(void);

extern mth_call_record *mth_getCallRecords(int *num);
extern void mth_clearCallRecords(void);

#endif /* MTHCallTraceCore_h */

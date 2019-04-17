//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2017/6/29
// Created by: YWH
//


#import <UIKit/UIKit.h>
#include <vector>
#import "MTHCPUTraceHighLoadRecord.h"

#ifndef MTH_CPUTraceDebugEnable
#define MTH_CPUTraceDebugEnable 0
#define MTH_CPUTracePerformanceEnable 0
#endif

#if MTH_CPUTraceDebugEnable
#define MTHCPUDebugLog(fmt, ...) printf(fmt, ##__VA_ARGS__)
#else
#define MTHCPUDebugLog(fmt, ...)
#endif


@protocol MTHCPUTracingDelegate;

@interface MTHCPUTrace : NSObject

/**
 When the CPU is under low load, the frequency to check the CPU usage. default 1 second.
 */
@property (nonatomic, assign) CGFloat checkIntervalIdle;

/**
 When the CPU is under high load, the frequency to check the CPU usage. default 0.3 second.
 */
@property (nonatomic, assign) CGFloat checkIntervalBusy;

/**
 Only care when the CPU usage exceeding the threshold. default 80%
 */
@property (nonatomic, assign) CGFloat highLoadThreshold;

/**
 Only dump StackFrame of the thread when it's CPU usage exceeding the threshold while sampling. default 15%
 */
@property (nonatomic, assign) CGFloat stackFramesDumpThreshold;

/**
 Only generate record when the high load lasting longer than limit. default 60 seconds.
 */
@property (nonatomic, assign) CGFloat highLoadLastingLimit;


+ (instancetype)shareInstance;

- (void)addDelegate:(id<MTHCPUTracingDelegate>)delegate;
- (void)removeDelegate:(id<MTHCPUTracingDelegate>)delegate;

- (void)startTracing;
- (void)stopTracing;
- (BOOL)isTracing;

@end

/****************************************************************************/
#pragma mark -

@protocol MTHCPUTracingDelegate <NSObject>

- (void)cpuHighLoadRecordStartAt:(NSTimeInterval)startAt
       didUpdateStackFrameSample:(MTH_CPUTraceStackFramesNode *)stackframeRootNode
                 averageCPUUsage:(CGFloat)averageCPUUsage
                     lastingTime:(CGFloat)lastingTime;

- (void)cpuHighLoadRecordDidEnd;

@end

//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/21
// Created by: EuanC
//


#import "MTHawkeyeUserDefaults.h"

NS_ASSUME_NONNULL_BEGIN

@interface MTHawkeyeUserDefaults (CPUMonitor)

@property (nonatomic, assign) BOOL cpuTraceOn;

/**
 When the CPU is under low load, the frequency to check the CPU usage. default 1 second.
 */
@property (nonatomic, assign) CGFloat cpuTraceCheckIntervalIdle;

/**
 When the CPU is under high load, the frequency to check the CPU usage. default 0.3 second.
 */
@property (nonatomic, assign) CGFloat cpuTraceCheckIntervalBusy;

/**
 Only care when the CPU usage exceeding the threshold. default 80%
 */
@property (nonatomic, assign) CGFloat cpuTraceHighLoadThreshold;

/**
 Only dump StackFrame of the thread when it's CPU usage exceeding the threshold while sampling. default 15%
 */
@property (nonatomic, assign) CGFloat cpuTraceStackFramesDumpThreshold;

/**
 Only generate record when the high load lasting longer than limit. default 60 seconds.
 */
@property (nonatomic, assign) CGFloat cpuTraceHighLoadLastingLimit;

@end

NS_ASSUME_NONNULL_END

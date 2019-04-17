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


#import "MTHCallTrace.h"
#import <objc/runtime.h>
#import <sys/time.h>

#import "MTHCallTraceCore.h"
#import "MTHCallTraceTimeCostModel.h"

#import <MTHawkeye/MTHawkeyeHooking.h>
#import <MTHawkeye/MTHawkeyeUtility.h>


NSString *const kHawkeyeCalltraceAutoLaunchKey = @"mth-calltrace-auto-launch-enabled";
NSString *const kHawkeyeCalltraceMaxDepthKey = @"mth-calltrace-max-depth";
NSString *const kHawkeyeCalltraceMinCostKey = @"mth-calltrace-min-cost";


@implementation MTHCallTrace

+ (void)setAutoStartAtLaunchEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kHawkeyeCalltraceAutoLaunchKey];
}

+ (BOOL)autoStartAtLaunchEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kHawkeyeCalltraceAutoLaunchKey];
}

+ (void)load {
    if ([MTHawkeyeUtility underUnitTest])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        BOOL needStart = [[NSUserDefaults standardUserDefaults] boolForKey:kHawkeyeCalltraceAutoLaunchKey];
        if (needStart) {
            [self startAtOnce];
        }
    });
}

+ (void)startAtOnce {
    if (mth_calltraceRunning())
        return;

    CGFloat costInMS = [[NSUserDefaults standardUserDefaults] floatForKey:kHawkeyeCalltraceMinCostKey];
    NSInteger depth = [[NSUserDefaults standardUserDefaults] integerForKey:kHawkeyeCalltraceMaxDepthKey];
    [self configureTraceTimeThreshold:costInMS];
    [self configureTraceMaxDepth:depth];
    [self start];
}

+ (void)disable {
    mth_calltraceStop();
}

+ (void)enable {
    mth_calltraceStart();
}

+ (BOOL)isRunning {
    return mth_calltraceRunning();
}

+ (void)start {
    mth_calltraceStart();
}

+ (void)configureTraceAll {
    mth_calltraceTraceAll();
}

+ (void)configureTraceByThreshold {
    mth_calltraceTraceByThreshold();
}

+ (void)configureTraceMaxDepth:(NSInteger)depth {
    if (depth > 0) {
        mth_calltraceConfigMaxDepth((int)depth);
        [[NSUserDefaults standardUserDefaults] setInteger:depth forKey:kHawkeyeCalltraceMaxDepthKey];
    }
}

+ (void)configureTraceTimeThreshold:(double)timeInMS {
    if (timeInMS > 0.f) {
        mth_calltraceConfigTimeThreshold((uint32_t)(timeInMS * 1000));
        [[NSUserDefaults standardUserDefaults] setFloat:timeInMS forKey:kHawkeyeCalltraceMinCostKey];
    }
}

+ (void)stop {
    mth_calltraceStop();
}

+ (int)currentTraceMaxDepth {
    return mth_calltraceMaxDepth();
}

+ (double)currentTraceTimeThreshold {
    return mth_calltraceTimeThreshold() / 1000;
}

+ (NSArray<MTHCallTraceTimeCostModel *> *)records {
    return [self recordsFromIndex:0];
}

+ (NSArray<MTHCallTraceTimeCostModel *> *)recordsFromIndex:(NSInteger)index {
    NSMutableArray<MTHCallTraceTimeCostModel *> *arr = @[].mutableCopy;
    int num = 0;
    mth_call_record *records = mth_getCallRecords(&num);
    if (index >= num) {
        return [arr copy];
    }

    for (int i = (int)index; i < num; ++i) {
        mth_call_record *record = &records[i];
        MTHCallTraceTimeCostModel *model = [MTHCallTraceTimeCostModel new];
        model.className = NSStringFromClass(record->cls);
        model.methodName = NSStringFromSelector(record->sel);
        model.isClassMethod = class_isMetaClass(record->cls);
        model.timeCostInMS = (double)record->cost * 1e-3;
        model.eventTime = record->event_time;
        model.callDepth = record->depth;
        [arr addObject:model];
    }
    return [arr copy];
}

+ (NSArray<MTHCallTraceTimeCostModel *> *)prettyRecords {
    NSArray *arr = [self records];
    NSUInteger count = arr.count;
    NSMutableArray *stack = [NSMutableArray array];
    for (NSUInteger i = 0; i < count; ++i) {
        MTHCallTraceTimeCostModel *top = stack.lastObject;
        MTHCallTraceTimeCostModel *item = arr[i];
        while (top && top.callDepth > item.callDepth) {
            NSMutableArray *sub = item.subCosts ? [item.subCosts mutableCopy] : @[].mutableCopy;
            [sub insertObject:top atIndex:0];
            item.subCosts = [sub copy];
            [stack removeLastObject]; // stack pop

            top = stack.lastObject;
        }
        [stack addObject:item];
    }

    NSArray *result = [stack copy];
    return result;
}

@end

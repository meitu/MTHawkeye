//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2019/7/4
// Created by: EuanC
//


#import <Foundation/Foundation.h>

#import <MTHawkeye/mth_stack_backtrace.h>

#define MTHawkeyeANRTracingDebugEnabled 0

#ifdef MTHawkeyeANRTracingDebugEnabled
#define _MTHawkeyeANRTracingDebugEnabled MTHawkeyeANRTracingDebugEnabled
#else
#define _MTHawkeyeANRTracingDebugEnabled NO
#endif


NS_ASSUME_NONNULL_BEGIN


#ifdef __cplusplus
extern "C" {
#endif

typedef NS_ENUM(NSInteger, MTHawkeyeAppLifeActivity) {
    MTHawkeyeAppLifeActivityUnknown = 0,
    MTHawkeyeAppLifeActivityWillEnterForeground = 1,
    MTHawkeyeAppLifeActivityDidEnterBackground,
    MTHawkeyeAppLifeActivityDidBecomeActive,
    MTHawkeyeAppLifeActivityWillResignActive,
    MTHawkeyeAppLifeActivityWillTerminate,
    MTHawkeyeAppLifeActivityMemoryWarning,               // received memory warning.
    MTHawkeyeAppLifeActivityBackgroundTaskWillOutOfTime, // background task running out of 175s.
};
extern NSString *mthStringFromAppLifeActivity(MTHawkeyeAppLifeActivity activity);
extern NSString *mthStringFromRunloopActivity(CFRunLoopActivity activity);

typedef struct _MTHawkeyeAppLifeActivityRecord {
    MTHawkeyeAppLifeActivity activity;
    NSTimeInterval time;
} MTHawkeyeAppLifeActivityRecord;

typedef struct _MTHawkeyeRunloopActivityRecord {
    CFRunLoopActivity activity;
    NSTimeInterval time;
} MTHawkeyeRunloopActivityRecord;


#if _MTHawkeyeANRTracingDebugEnabled
static const int kMTHawkeyeRunloopActivitiesBufferCount = 300;
#else
static const int kMTHawkeyeRunloopActivitiesBufferCount = 30;
#endif
static const int kMTHawkeyeAppLifeActivitiesBufferCount = 10;
static const int kMTHawkeyeStackBacktracesBufferLimit = 500;

typedef struct _MTHANRTracingBufferContext {
    NSUInteger size; // use to detect whether the size has between two session.
    NSUInteger runloopActivitiesStartIndex;
    NSUInteger appLifeActivitiesStartIndex;
    NSUInteger stackFramesStartIndex;

    MTHawkeyeRunloopActivityRecord runloopActivities[kMTHawkeyeRunloopActivitiesBufferCount];
    MTHawkeyeAppLifeActivityRecord appLifeActivities[kMTHawkeyeAppLifeActivitiesBufferCount];
    uintptr_t stackBacktraces[kMTHawkeyeStackBacktracesBufferLimit];
} MTHANRTracingBufferContext;

#ifdef __cplusplus
} // extern "C"
#endif


// MARK: -

@interface MTHANRTracingBuffer : NSObject

/// Will check the last applife activity, while equal to `willTerminate` or `didEnterBackground`,
/// `isAppStillActiveTheLastMoment` is YES, which means normally exit as expected in that session.
@property (nonatomic, assign, readonly) BOOL isAppStillActiveTheLastMoment;

/// While ANRTracing capture the App is still active at the last time
/// We'll check if there exist main thread backtrace after the last captured runloop activity
/// If exist, `isDuringHardStall` is YES, else NO.
@property (nonatomic, assign, readonly) BOOL isDuringHardStall;

@property (nonatomic, assign, readonly) NSTimeInterval hardStallDurationInSeconds;

@property (nonatomic, assign, readonly) BOOL isLastAppActivityBackgroundTaskWillRunOutOfTime;

/*
 make datastruct simple (reduce classes used), times & activities are in pair.
 */
@property (nonatomic, copy) NSArray<NSNumber *> *runloopActivitiesTimes;
@property (nonatomic, copy) NSArray<NSNumber *> *runloopActivities;

@property (nonatomic, copy) NSArray<NSNumber *> *applifeActivitiesTimes;
@property (nonatomic, copy) NSArray<NSNumber *> *applifeActivities;

@property (nonatomic, copy) NSArray<NSNumber *> *backtraceRecordTimes;
@property (nonatomic, copy) NSArray<NSArray<NSNumber *> *> *backtraceRecords;

- (NSTimeInterval)lastRunloopAcvitityTime;
- (CFRunLoopActivity)lastRunloopActivity;

@end


// MARK: -

/**
 Sometime the stall may turn to hard stall and been killed by the watchdog(or user).
 We need a buffer to cache the context on that case, for detail it's a mmap file.
 We'll create a fixed size memory and map to a mmap file,
 we cache the currently main thread runloop activities, App life activities,
 and sample stackframes of main thread.

 Once the App killed by system because of hard stall, we can retrieve the latest records
 from the mmap file, and find out the details of the hard stall.

 Memory Impact: for memory mmapping only works on entire pages of memory,
                it would use 16KB ( pagesize() on 64bit devices ) mmapping memory.
 */
@interface MTHANRTracingBufferRunner : NSObject

+ (BOOL)isTracingBufferRunning;
+ (BOOL)enableTracingBufferAtPath:(NSString *)bufferFilePath;
+ (void)disableTracingBuffer;

+ (BOOL)traceRunloopActivity:(CFRunLoopActivity)activity;
+ (BOOL)traceAppLifeActivity:(MTHawkeyeAppLifeActivity)activity;
+ (BOOL)traceStackBacktrace:(mth_stack_backtrace *)backtrace;


+ (void)readCurrentSessionBufferWithCompletionHandler:(void (^)(MTHANRTracingBuffer *_Nullable buffer))completionHandler;

+ (void)readPreviousSessionBufferAtPath:(NSString *)bufferFilePath
                      completionHandler:(void (^)(MTHANRTracingBuffer *_Nullable buffer))completionHandler;

@end

NS_ASSUME_NONNULL_END

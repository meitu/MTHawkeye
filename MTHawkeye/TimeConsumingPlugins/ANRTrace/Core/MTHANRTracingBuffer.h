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

static const int kMTHawkeyeRunloopActivitiesBufferCount = 30;
static const int kMTHawkeyeAppLifeActivitiesBufferCount = 10;
static const int kMTHawkeyeStackBacktracesBufferLimit = 500;

typedef struct _MTHANRTracingBufferContext {
    NSUInteger runloopActivitiesStartIndex;
    NSUInteger appLifeActivitiesStartIndex;
    NSUInteger stackFramesStartIndex;

    MTHawkeyeRunloopActivityRecord runloopActivities[kMTHawkeyeRunloopActivitiesBufferCount];
    MTHawkeyeAppLifeActivityRecord appLifeActivities[kMTHawkeyeAppLifeActivitiesBufferCount];
    uintptr_t stackBacktraces[kMTHawkeyeStackBacktracesBufferLimit];
} MTHANRTracingBufferContext;

extern NSDictionary *mthDictionaryFromANRTracingBufferContext(MTHANRTracingBufferContext *context);
extern MTHANRTracingBufferContext mthANRTracingBufferContextFromMmapFile(NSString *filepath);


#ifdef __cplusplus
} // extern "C"
#endif

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
@interface MTHANRTracingBuffer : NSObject

+ (BOOL)isTracingBufferRunning;
+ (BOOL)enableTracingBufferAtPath:(NSString *)bufferFilePath;
+ (void)disableTracingBuffer;

+ (BOOL)traceRunloopActivity:(CFRunLoopActivity)activity;
+ (BOOL)traceAppLifeActivity:(MTHawkeyeAppLifeActivity)activity;
+ (BOOL)traceStackBacktrace:(mth_stack_backtrace *)backtrace;


/**
 Dictionary Example:
 {
    "runloop": [
        {"time": 1562313106.134135, "activity": "beforeWaiting"},
        ...
    ],
    "applife": [
        {"time": 1562313106.134135, "activity": "didEnterBackground"},
        ...
    ],
    "stackbacktrace": [
        {"time": 1562313106.134135, "frames": "0x10235125,0x10324534,0x10884281"},
        ...
    ]
 }
 */
+ (void)readCurrentSessionBufferInDict:(void (^)(NSDictionary *_Nullable context))completionHandler;

+ (void)readPreviousSessionBufferAtPath:(NSString *)bufferFilePath
                       completionInDict:(void (^)(NSDictionary *_Nullable context))completionHandler;

@end

NS_ASSUME_NONNULL_END

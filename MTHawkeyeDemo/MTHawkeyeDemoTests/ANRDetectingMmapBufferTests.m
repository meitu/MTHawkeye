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


#import <MTHawkeye/MTHANRTracingBuffer.h>
#import <MTHawkeye/MTHawkeyeDyldImagesUtils.h>
#import <MTHawkeye/MTHawkeyeUtility.h>
#import <XCTest/XCTest.h>

@interface ANRDetectingMmapBufferTests : XCTestCase

@end

@implementation ANRDetectingMmapBufferTests

- (NSString *)testBufferPath {
    return [[MTHawkeyeUtility currentStorePath] stringByAppendingPathComponent:@"anr_buffer_test"];
}

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [MTHANRTracingBufferRunner disableTracingBuffer];
    [MTHANRTracingBufferRunner enableTracingBufferAtPath:[self testBufferPath]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.

    [MTHANRTracingBufferRunner disableTracingBuffer];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

- (void)testRunloopActivitiesCache {

    // cache 3 elements, read
    [MTHANRTracingBufferRunner traceRunloopActivity:kCFRunLoopAfterWaiting];
    [MTHANRTracingBufferRunner traceRunloopActivity:kCFRunLoopAfterWaiting];
    [MTHANRTracingBufferRunner traceRunloopActivity:kCFRunLoopAfterWaiting];

    [MTHANRTracingBufferRunner readCurrentSessionBufferWithCompletionHandler:^(MTHANRTracingBuffer *_Nullable buffer) {
        XCTAssert(buffer.runloopActivities.count == buffer.runloopActivitiesTimes.count);
        XCTAssert(buffer.runloopActivities.count == 3);

        XCTAssert(buffer.applifeActivities.count == 0);
        XCTAssert(buffer.backtraceRecords.count == 0);
    }];

    // insert ..., replace 2 of 3 (remain one), read
    for (NSInteger i = 0; i < kMTHawkeyeRunloopActivitiesBufferCount - 1; ++i) {
        [MTHANRTracingBufferRunner traceRunloopActivity:kCFRunLoopBeforeWaiting];
    }
    [MTHANRTracingBufferRunner readCurrentSessionBufferWithCompletionHandler:^(MTHANRTracingBuffer *_Nullable buffer) {
        XCTAssert(buffer != nil);
        XCTAssert(buffer.runloopActivities.count == buffer.runloopActivitiesTimes.count);

        NSArray *runloopActivities = buffer.runloopActivities;
        XCTAssert(runloopActivities.count == kMTHawkeyeRunloopActivitiesBufferCount, @"should full now.");

        XCTAssert([runloopActivities.lastObject integerValue] == (NSInteger)kCFRunLoopBeforeWaiting);
        XCTAssert([runloopActivities.firstObject integerValue] == (NSInteger)kCFRunLoopAfterWaiting);
    }];
}

- (void)testApplifeActivitiesCache {
    // cache
    [MTHANRTracingBufferRunner traceAppLifeActivity:MTHawkeyeAppLifeActivityDidBecomeActive];
    [MTHANRTracingBufferRunner traceAppLifeActivity:MTHawkeyeAppLifeActivityWillResignActive];
    [MTHANRTracingBufferRunner traceAppLifeActivity:MTHawkeyeAppLifeActivityDidEnterBackground];

    [MTHANRTracingBufferRunner readCurrentSessionBufferWithCompletionHandler:^(MTHANRTracingBuffer *_Nullable buffer) {
        XCTAssert(buffer != nil);
        XCTAssert(buffer.applifeActivities.count == buffer.applifeActivitiesTimes.count);

        NSArray *applifes = buffer.applifeActivities;
        XCTAssert(applifes.count == 3, @"runloop record should be equal.");

        XCTAssert([applifes[0] integerValue] == (NSInteger)MTHawkeyeAppLifeActivityDidBecomeActive);
        XCTAssert([applifes[1] integerValue] == (NSInteger)MTHawkeyeAppLifeActivityWillResignActive);
        XCTAssert([applifes[2] integerValue] == (NSInteger)MTHawkeyeAppLifeActivityDidEnterBackground);
    }];

    // replace 1 of 3, (remain two)
    for (NSInteger i = 0; i < kMTHawkeyeAppLifeActivitiesBufferCount - 2; ++i) {
        [MTHANRTracingBufferRunner traceAppLifeActivity:MTHawkeyeAppLifeActivityWillTerminate];
    }

    [MTHANRTracingBufferRunner readCurrentSessionBufferWithCompletionHandler:^(MTHANRTracingBuffer *_Nullable buffer) {
        XCTAssert(buffer != nil);
        XCTAssert(buffer.applifeActivities.count == buffer.applifeActivitiesTimes.count);

        NSArray *applifes = buffer.applifeActivities;
        XCTAssert(applifes.count == kMTHawkeyeAppLifeActivitiesBufferCount, @"runloop record should be equal.");

        XCTAssert([applifes[0] integerValue] == (NSInteger)MTHawkeyeAppLifeActivityWillResignActive);
        XCTAssert([applifes[1] integerValue] == (NSInteger)MTHawkeyeAppLifeActivityDidEnterBackground);
        XCTAssert([applifes[2] integerValue] == (NSInteger)MTHawkeyeAppLifeActivityWillTerminate);
        XCTAssert([[applifes lastObject] integerValue] == (NSInteger)MTHawkeyeAppLifeActivityWillTerminate);
    }];
}

- (void)testStackFramesCache {
    NSArray *backtraceList = @[
        @[ @(100), @(101), @(102), @(103) ],
        @[ @(200), @(201), @(202), @(203) ],
        @[ @(300), @(301), @(302), @(303), @(304), @(305), @(306) ],
    ];

    NSInteger existCount = 0;
    for (NSArray *item in backtraceList) {
        [self traceBacktrace:item];
        existCount += (item.count + 2); // 2 extra for frame_size, time storage
    }

    [MTHANRTracingBufferRunner readCurrentSessionBufferWithCompletionHandler:^(MTHANRTracingBuffer *_Nullable buffer) {
        NSArray *backtraceRecords = buffer.backtraceRecords;
        XCTAssert(backtraceRecords.count == backtraceList.count);

        [self assertFrames:[backtraceRecords lastObject] equalToFramesInNumber:[backtraceList lastObject]];
    }];

    NSArray *newerBacktrace = @[ @(1001), @(1002), @(1003), @(1004), @(1005), @(1006), @(1007), @(1008) ];

    NSInteger remainOldBacktraceCount = 5;                                                                // @(300), @(301), @(302), @(303), @(304) // 5
    NSInteger midCount = kMTHawkeyeStackBacktracesBufferLimit - existCount + remainOldBacktraceCount + 2; // 2 extra for frame_size, time storage
    midCount -= newerBacktrace.count;
    NSInteger insertFramesCount = 0;
    NSInteger midBacktraceCount = 0;
    for (; insertFramesCount < midCount;) {
        [self traceBacktrace:newerBacktrace];
        insertFramesCount += (newerBacktrace.count + 2);
        midBacktraceCount += 1;
    }

    NSInteger latestCount = kMTHawkeyeStackBacktracesBufferLimit - insertFramesCount - (remainOldBacktraceCount + 2) - 2;
    NSMutableArray *lastestBacktrace = @[].mutableCopy;
    for (NSInteger i = 0; i < latestCount; ++i) {
        [lastestBacktrace addObject:@(2001 + i)];
    }
    [self traceBacktrace:lastestBacktrace];

    __block BOOL callbacked = NO;
    [MTHANRTracingBufferRunner readCurrentSessionBufferWithCompletionHandler:^(MTHANRTracingBuffer *_Nullable buffer) {
        callbacked = YES;

        NSArray *backtraces = buffer.backtraceRecords;
        XCTAssert(backtraces.count == midBacktraceCount + 1 /*lastestBacktrace*/ + 1 /*the only remain*/);

        NSArray<NSNumber *> *firstBacktrace = [backtraces firstObject];
        NSArray<NSNumber *> *lastBacktrace = [backtraces lastObject];

        NSArray *orgFirstBracetrace = [[backtraceList lastObject] subarrayWithRange:NSMakeRange(0, remainOldBacktraceCount)];
        [self assertFrames:firstBacktrace equalToFramesInNumber:orgFirstBracetrace];
        [self assertFrames:lastBacktrace equalToFramesInNumber:lastestBacktrace];
    }];

    XCTAssert(callbacked);
}


- (void)testPreviousANRContextCache {
    [MTHANRTracingBufferRunner traceRunloopActivity:kCFRunLoopBeforeSources];
    [MTHANRTracingBufferRunner traceRunloopActivity:kCFRunLoopBeforeSources];
    [MTHANRTracingBufferRunner traceRunloopActivity:kCFRunLoopExit];

    [MTHANRTracingBufferRunner traceAppLifeActivity:MTHawkeyeAppLifeActivityWillTerminate];
    [MTHANRTracingBufferRunner traceAppLifeActivity:MTHawkeyeAppLifeActivityWillEnterForeground];
    [MTHANRTracingBufferRunner traceAppLifeActivity:MTHawkeyeAppLifeActivityDidBecomeActive];

    NSArray *backtraceList = @[
        @[ @(100), @(101), @(102), @(103) ],
        @[ @(200), @(201), @(202), @(203) ],
        @[ @(300), @(301), @(302), @(303), @(304), @(305), @(306) ],
    ];

    for (NSArray *item in backtraceList) {
        [self traceBacktrace:item];
    }

    [MTHANRTracingBufferRunner disableTracingBuffer];

    __block BOOL callbacked = NO;
    [MTHANRTracingBufferRunner
        readPreviousSessionBufferAtPath:[self testBufferPath]
                      completionHandler:^(MTHANRTracingBuffer *_Nullable buffer) {
                          callbacked = YES;
                          NSArray *runloopActivities = buffer.runloopActivities;
                          XCTAssert(runloopActivities.count == 3, @"runloop record should be equal.");
                          XCTAssert([runloopActivities[2] integerValue] == (NSInteger)kCFRunLoopExit);

                          // applife
                          NSArray *applifes = buffer.applifeActivities;
                          XCTAssert(applifes.count == 3, @"runloop record should be equal.");

                          XCTAssert([applifes[0] integerValue] == (NSInteger)MTHawkeyeAppLifeActivityWillTerminate);
                          XCTAssert([applifes[1] integerValue] == (NSInteger)MTHawkeyeAppLifeActivityWillEnterForeground);
                          XCTAssert([applifes[2] integerValue] == (NSInteger)MTHawkeyeAppLifeActivityDidBecomeActive);

                          // bt
                          NSArray *backtraceRecords = buffer.backtraceRecords;
                          XCTAssert(backtraceRecords.count == backtraceList.count);

                          NSArray<NSNumber *> *lastBacktrace = [backtraceRecords lastObject];
                          [self assertFrames:lastBacktrace equalToFramesInNumber:[backtraceList lastObject]];
                      }];

    XCTAssert(callbacked);
}

// test after enter background, the tracing.

// test resume from background, the tracing.


// MARK: - helper
- (void)traceBacktrace:(NSArray<NSNumber *> *)frames {
    mth_stack_backtrace *bt = mth_malloc_stack_backtrace();

    bt->frames_size = frames.count;
    bt->frames = (uintptr_t *)malloc(sizeof(uintptr_t) * frames.count);

    for (NSInteger i = 0; i < frames.count; ++i) {
        bt->frames[i] = (uintptr_t)[frames[i] integerValue];
    }

    [MTHANRTracingBufferRunner traceStackBacktrace:bt];

    mth_free_stack_backtrace(bt);
}

- (void)assertFrames:(NSArray<NSNumber *> *)framesInNumberA equalToFramesInNumber:(NSArray *)framesInNumberB {
    XCTAssert(framesInNumberA.count == framesInNumberB.count);

    for (NSInteger i = 0; i < framesInNumberA.count; ++i) {
        XCTAssert(i < framesInNumberB.count);

        if (i < framesInNumberB.count) {
            XCTAssert([framesInNumberA[i] integerValue] == [framesInNumberB[i] integerValue]);
        }
    }
}

@end

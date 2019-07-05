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
    return [[MTHawkeyeUtility hawkeyeStoreDirectory] stringByAppendingPathComponent:@"anr_buffer_test"];
}

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [MTHANRTracingBuffer disableTracingBuffer];
    [MTHANRTracingBuffer enableTracingBufferOn:[self testBufferPath]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.

    [MTHANRTracingBuffer disableTracingBuffer];
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
    [MTHANRTracingBuffer traceRunloopActivity:kCFRunLoopAfterWaiting];
    [MTHANRTracingBuffer traceRunloopActivity:kCFRunLoopAfterWaiting];
    [MTHANRTracingBuffer traceRunloopActivity:kCFRunLoopAfterWaiting];

    [MTHANRTracingBuffer readCurrentSessionBufferInDict:^(NSDictionary *_Nullable context) {
        NSArray *runloop = context[@"runloop"];
        XCTAssert(runloop.count == 3, @"runloop record should be equal.");
    }];

    // insert ..., replace 2 of 3 (remain one), read
    for (NSInteger i = 0; i < kMTHawkeyeRunloopActivitiesBufferCount - 1; ++i) {
        [MTHANRTracingBuffer traceRunloopActivity:kCFRunLoopBeforeWaiting];
    }
    [MTHANRTracingBuffer readCurrentSessionBufferInDict:^(NSDictionary *_Nullable context) {
        NSArray *runloop = context[@"runloop"];
        XCTAssert(runloop.count == kMTHawkeyeRunloopActivitiesBufferCount, @"should full now.");

        NSDictionary *last = [runloop lastObject];
        XCTAssert([last[@"activity"] isEqualToString:mthStringFromRunloopActivity(kCFRunLoopBeforeWaiting)], @"last activity should be right");

        NSDictionary *first = [runloop firstObject];
        XCTAssert([first[@"activity"] isEqualToString:mthStringFromRunloopActivity(kCFRunLoopAfterWaiting)], @"first activity should be right");
    }];
}

- (void)testApplifeActivitiesCache {
    // cache
    [MTHANRTracingBuffer traceAppLifeActivity:MTHawkeyeAppLifeActivityDidBecomeActive];
    [MTHANRTracingBuffer traceAppLifeActivity:MTHawkeyeAppLifeActivityWillResignActive];
    [MTHANRTracingBuffer traceAppLifeActivity:MTHawkeyeAppLifeActivityDidEnterBackground];

    [MTHANRTracingBuffer readCurrentSessionBufferInDict:^(NSDictionary *_Nullable context) {
        NSArray *applifes = context[@"applife"];
        XCTAssert(applifes.count == 3, @"runloop record should be equal.");

        XCTAssert([applifes[0][@"activity"] isEqualToString:mthStringFromAppLifeActivity(MTHawkeyeAppLifeActivityDidBecomeActive)]);
        XCTAssert([applifes[1][@"activity"] isEqualToString:mthStringFromAppLifeActivity(MTHawkeyeAppLifeActivityWillResignActive)]);
        XCTAssert([applifes[2][@"activity"] isEqualToString:mthStringFromAppLifeActivity(MTHawkeyeAppLifeActivityDidEnterBackground)]);
    }];

    // replace 1 of 3, (remain two)
    for (NSInteger i = 0; i < kMTHawkeyeAppLifeActivitiesBufferCount - 2; ++i) {
        [MTHANRTracingBuffer traceAppLifeActivity:MTHawkeyeAppLifeActivityWillTerminate];
    }

    [MTHANRTracingBuffer readCurrentSessionBufferInDict:^(NSDictionary *_Nullable context) {
        NSArray *applifes = context[@"applife"];
        XCTAssert(applifes.count == kMTHawkeyeAppLifeActivitiesBufferCount, @"runloop record should be equal.");

        XCTAssert([applifes[0][@"activity"] isEqualToString:mthStringFromAppLifeActivity(MTHawkeyeAppLifeActivityWillResignActive)]);
        XCTAssert([applifes[1][@"activity"] isEqualToString:mthStringFromAppLifeActivity(MTHawkeyeAppLifeActivityDidEnterBackground)]);
        XCTAssert([applifes[2][@"activity"] isEqualToString:mthStringFromAppLifeActivity(MTHawkeyeAppLifeActivityWillTerminate)]);
        XCTAssert([[applifes lastObject][@"activity"] isEqualToString:mthStringFromAppLifeActivity(MTHawkeyeAppLifeActivityWillTerminate)]);
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

    [MTHANRTracingBuffer readCurrentSessionBufferInDict:^(NSDictionary *_Nullable context) {
        NSArray *backtraces = context[@"stackbacktrace"];
        XCTAssert(backtraces.count == backtraceList.count);

        NSDictionary *last = [backtraces lastObject];
        NSString *frames = last[@"frames"];
        [self assertFrames:frames equalToFramesInNumber:[backtraceList lastObject]];
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

    [MTHANRTracingBuffer readCurrentSessionBufferInDict:^(NSDictionary *_Nullable context) {
        NSArray *backtraces = context[@"stackbacktrace"];
        XCTAssert(backtraces.count == midBacktraceCount + 1 /*lastestBacktrace*/ + 1 /*the only remain*/);

        NSDictionary *first = [backtraces firstObject];
        NSDictionary *last = [backtraces lastObject];

        NSArray *orgFirstBracetrace = [[backtraceList lastObject] subarrayWithRange:NSMakeRange(0, remainOldBacktraceCount)];
        [self assertFrames:first[@"frames"] equalToFramesInNumber:orgFirstBracetrace];
        [self assertFrames:last[@"frames"] equalToFramesInNumber:lastestBacktrace];
    }];
}


- (void)testPreviousANRContextCache {
    [MTHANRTracingBuffer traceRunloopActivity:kCFRunLoopBeforeSources];
    [MTHANRTracingBuffer traceRunloopActivity:kCFRunLoopBeforeSources];
    [MTHANRTracingBuffer traceRunloopActivity:kCFRunLoopExit];

    [MTHANRTracingBuffer traceAppLifeActivity:MTHawkeyeAppLifeActivityWillTerminate];
    [MTHANRTracingBuffer traceAppLifeActivity:MTHawkeyeAppLifeActivityWillEnterForeground];
    [MTHANRTracingBuffer traceAppLifeActivity:MTHawkeyeAppLifeActivityDidBecomeActive];

    NSArray *backtraceList = @[
        @[ @(100), @(101), @(102), @(103) ],
        @[ @(200), @(201), @(202), @(203) ],
        @[ @(300), @(301), @(302), @(303), @(304), @(305), @(306) ],
    ];

    for (NSArray *item in backtraceList) {
        [self traceBacktrace:item];
    }

    // trigger backup
    [MTHANRTracingBuffer disableTracingBuffer];
    [MTHANRTracingBuffer enableTracingBufferOn:[self testBufferPath]];

    [MTHANRTracingBuffer readPreviousSessionBufferInDict:^(NSDictionary *_Nullable context) {
        NSArray *runloop = context[@"runloop"];
        XCTAssert(runloop.count == 3, @"runloop record should be equal.");
        XCTAssert([runloop[2][@"activity"] isEqualToString:mthStringFromRunloopActivity(kCFRunLoopExit)]);

        // applife
        NSArray *applifes = context[@"applife"];
        XCTAssert(applifes.count == 3, @"runloop record should be equal.");

        XCTAssert([applifes[0][@"activity"] isEqualToString:mthStringFromAppLifeActivity(MTHawkeyeAppLifeActivityWillTerminate)]);
        XCTAssert([applifes[1][@"activity"] isEqualToString:mthStringFromAppLifeActivity(MTHawkeyeAppLifeActivityWillEnterForeground)]);
        XCTAssert([applifes[2][@"activity"] isEqualToString:mthStringFromAppLifeActivity(MTHawkeyeAppLifeActivityDidBecomeActive)]);

        // bt
        NSArray *backtraces = context[@"stackbacktrace"];
        XCTAssert(backtraces.count == backtraceList.count);

        NSDictionary *last = [backtraces lastObject];
        NSString *frames = last[@"frames"];
        [self assertFrames:frames equalToFramesInNumber:[backtraceList lastObject]];
    }];
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

    [MTHANRTracingBuffer traceStackBacktrace:bt];

    mth_free_stack_backtrace(bt);
}

- (void)assertFrames:(NSString *)framesInString equalToFramesInNumber:(NSArray *)framesInNumber {
    NSMutableString *framesInStringFromNumber = [NSMutableString string];
    for (NSNumber *item in framesInNumber) {
        [framesInStringFromNumber appendFormat:@"%p,", (void *)[item integerValue]];
    }
    NSString *frames = [framesInStringFromNumber substringToIndex:framesInStringFromNumber.length - 1];

    XCTAssert([framesInString isEqualToString:frames]);
}

@end

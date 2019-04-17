//
//  MTNetworkMonitorViewModelTests.m
//  MTHawkeyeDemoTests
//
//  Created by EuanC on 17/07/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <MTHawkeye/MTHNetworkMonitorViewModel.h>
#import "MTHNetworkTransaction.h"

@interface MTHNetworkMonitorViewModel (Test)

@property (nonatomic, copy) NSArray<MTHNetworkTransaction *> *networkTransactions;

@end


/****************************************************************************/
#pragma mark -


@interface NetworkMonitorViewModelTests : XCTestCase

@property (nonatomic, assign) NSTimeInterval baseTime;

@end

@implementation NetworkMonitorViewModelTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.

    if (self.baseTime == 0) {
        self.baseTime = [[NSDate date] timeIntervalSince1970];
    }
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
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

// 聚焦的请求已返回
- (void)testCompletedFocus {
    NSArray *listData = @[
        @(0), @(0),   // 1: 0 ~ ∞
        @(3), @(15),  // 2: (3, 15)
        @(8), @(9),   // 3: out.
        @(8), @(10),  // 4: (8, 10) out.
        @(8), @(11),  // 5: (8, 11)
        @(10), @(20), // 6: focus (10, 20)
        @(15), @(18), // 7: (15, 18)
        @(15), @(22), // 8: (15, 22)
        @(15), @(15), // 9: 15 ~ ∞
        @(20), @(21), // 10: (20, 21), out
        @(21), @(23)  // 11: out.
    ];
    NSArray<MTHNetworkTransaction *> *transList = [self transactionListFromRanges:listData];
    MTHNetworkMonitorViewModel *viewModel = [[MTHNetworkMonitorViewModel alloc] init];
    viewModel.networkTransactions = transList;
    XCTAssert(viewModel.requestIndexFocusOnCurrently < 0);
    XCTAssert(viewModel.currentOnViewIndexArray.count == 0);
    [viewModel focusOnTransactionWithRequestIndex:6];

    XCTAssert(viewModel.requestIndexFocusOnCurrently == 6);
    NSArray<NSNumber *> *onViewList = viewModel.currentOnViewIndexArray;
    XCTAssert(onViewList.count == 7);
    XCTAssert([onViewList[0] integerValue] == 1);
    XCTAssert([onViewList[1] integerValue] == 2);
    XCTAssert([onViewList[2] integerValue] == 5);
    XCTAssert([onViewList[3] integerValue] == 6);
    XCTAssert([onViewList[4] integerValue] == 7);
    XCTAssert([onViewList[5] integerValue] == 8);
    XCTAssert([onViewList[6] integerValue] == 9);
}

// 聚焦的请求未返回
- (void)testNoResponseFoncus {
    NSArray *listData = @[
        @(0), @(0),   // 1: 0 ~ ∞
        @(3), @(15),  // 2: (3, 15)
        @(8), @(9),   // 3: out.
        @(8), @(10),  // 4: (8, 10) out.
        @(8), @(11),  // 5: (8, 11)
        @(10), @(10), // 6: focus (10, ~ ∞
        @(15), @(18), // 7: (15, 18)
        @(15), @(22), // 8: (15, 22)
        @(15), @(15), // 9: 15 ~ ∞
        @(20), @(21), // 10: (20, 21)
        @(21), @(23)  // 11: (21, 23)
    ];
    NSArray<MTHNetworkTransaction *> *transList = [self transactionListFromRanges:listData];
    MTHNetworkMonitorViewModel *viewModel = [[MTHNetworkMonitorViewModel alloc] init];
    viewModel.networkTransactions = transList;
    viewModel.maxFollowingWhenFocusNotResponse = 4;
    XCTAssert(viewModel.requestIndexFocusOnCurrently < 0);
    XCTAssert(viewModel.currentOnViewIndexArray.count == 0);
    [viewModel focusOnTransactionWithRequestIndex:6];

    XCTAssert(viewModel.requestIndexFocusOnCurrently == 6);
    NSArray<NSNumber *> *onViewList = viewModel.currentOnViewIndexArray;
    XCTAssert(onViewList.count == 9);
    XCTAssert([onViewList[0] integerValue] == 1);
    XCTAssert([onViewList[1] integerValue] == 2);
    XCTAssert([onViewList[2] integerValue] == 5);
    XCTAssert([onViewList[3] integerValue] == 6);
    XCTAssert([onViewList[4] integerValue] == 7);
    XCTAssert([onViewList[5] integerValue] == 8);
    XCTAssert([onViewList[6] integerValue] == 9);
    XCTAssert([onViewList[7] integerValue] == 10);
    XCTAssert([onViewList[8] integerValue] == 11);
}

- (NSArray<MTHNetworkTransaction *> *)transactionListFromRanges:(NSArray *)ranges {
    NSMutableArray *list = [NSMutableArray array];
    for (NSInteger i = 0; i < ranges.count; i += 2) {
        NSInteger location = [ranges[i] integerValue];
        NSInteger length = [ranges[i + 1] integerValue] - location;
        MTHNetworkTransaction *item = [self transactionWithRange:NSMakeRange(location, length)];
        [list addObject:item];
    }

    for (NSInteger i = 0; i < list.count; ++i) {
        [list[i] setRequestIndex:(i + 1)];
    }
    return [list.reverseObjectEnumerator allObjects];
}

- (MTHNetworkTransaction *)transactionWithRange:(NSRange)range {
    NSTimeInterval start = self.baseTime + range.location;
    return [self generateTransactionWithStart:start latency:1 duration:range.length];
}

- (MTHNetworkTransaction *)generateTransactionWithStart:(NSTimeInterval)start latency:(NSTimeInterval)latency duration:(NSTimeInterval)duration {
    MTHNetworkTransaction *trans = [[MTHNetworkTransaction alloc] init];
    trans.startTime = [NSDate dateWithTimeIntervalSince1970:start];
    trans.latency = latency;
    trans.duration = duration;
    if (duration == 0) {
        trans.transactionState = MTHNetworkTransactionStateAwaitingResponse;
    } else {
        trans.transactionState = MTHNetworkTransactionStateFinished;
    }
    return trans;
}

@end

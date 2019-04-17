//
//  CallTraceTests.m
//  MTHawkeyeDemoTests
//
//  Created by EuanC on 2018/4/4.
//  Copyright © 2018 Meitu. All rights reserved.
//

#import <MTHawkeye/MTHCallTrace.h>
#import <XCTest/XCTest.h>

@interface CallTraceTests : XCTestCase

@end

@implementation CallTraceTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testBasicFlow {
    //    [MTHCallTrace startAtOnce];
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end

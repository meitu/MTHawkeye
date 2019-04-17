//
//  MTHawkeyeUserDefaultsTests.m
//  MTHawkeyeDemoTests
//
//  Created by EuanC on 2019/1/16.
//  Copyright © 2019 Meitu. All rights reserved.
//

#import <MTHawkeye/MTHawkeyeUserDefaults.h>
#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper/AGAsyncTestHelper.h>

@interface MTHawkeyeUserDefaults (_TestPrivate)
@property (nonatomic, strong) NSMapTable<NSString *, NSMutableArray *> *observerHandlers;
@end

/****************************************************************************/
#pragma mark -

@interface MTHawkeyeUserDefaultsTests : XCTestCase

@property (nonatomic, strong) MTHawkeyeUserDefaults *defaults;

@end

@implementation MTHawkeyeUserDefaultsTests

- (void)setUp {
    self.defaults = [[MTHawkeyeUserDefaults alloc] init];

    [self.defaults setObject:@"1" forKey:@"number"];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
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

- (void)testAddObserver {
    __block BOOL didNotifyA1 = NO, didNotifyA2 = NO, didNotifyB1 = NO, didNotifyB2 = NO, didNotifyC = NO;
    [self.defaults mth_addObserver:self
                            forKey:@"number"
                       withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                           if (!didNotifyA1) {
                               XCTAssertTrue([newValue isEqualToString:@"2"]);
                               didNotifyA1 = YES;
                           } else {
                               XCTAssertTrue([newValue isEqualToString:@"3"]);
                               didNotifyA2 = YES;
                           }
                       }];

    [self.defaults mth_addObserver:self
                            forKey:@"number"
                       withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                           if (!didNotifyB1) {
                               XCTAssertTrue([newValue isEqualToString:@"2"]);
                               didNotifyB1 = YES;
                           } else {
                               XCTAssertTrue([newValue isEqualToString:@"3"]);
                               didNotifyB2 = YES;
                           }
                       }];

    [[MTHawkeyeUserDefaults shared] mth_addObserver:self
                                             forKey:@"number1"
                                        withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                                            didNotifyC = NO;
                                        }];

    [self.defaults setObject:@"2" forKey:@"number"];

    [self.defaults setObject:@"3" forKey:@"number"];

    AGWW_WAIT_WHILE(didNotifyA2 == NO && didNotifyB2 == NO, 3.f, @"");
}

- (void)testRemoveObserver {
    [self.defaults mth_addObserver:self
                            forKey:@"number"
                       withHandler:^(id _Nullable oldValue, id _Nullable newValue){

                       }];
    [self.defaults mth_addObserver:self
                            forKey:@"number1"
                       withHandler:^(id _Nullable oldValue, id _Nullable newValue){

                       }];
    [self.defaults mth_addObserver:self
                            forKey:@"number"
                       withHandler:^(id _Nullable oldValue, id _Nullable newValue){

                       }];

    XCTAssert(self.defaults.observerHandlers.count == 2);

    [self.defaults mth_removeObserver:self forKey:@"number1"];

    XCTAssert(self.defaults.observerHandlers.count == 1);

    [self.defaults mth_removeObserver:self forKey:@"number"];

    XCTAssert(self.defaults.observerHandlers.count == 1);

    [self.defaults mth_removeObserver:self forKey:@"number"];

    XCTAssert(self.defaults.observerHandlers.count == 0);
}

@end

//
//  TransactionsFilterTests.m
//  MTHawkeyeDemoTests
//
//  Created by EuanC on 02/08/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "MTHNetworkTransactionsURLFilter.h"

@interface NetworkTransactionsFilterTests : XCTestCase

@end

@implementation NetworkTransactionsFilterTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)test_d1 {
    NSString *params1 = @"d ";
    MTHNetworkTransactionsURLFilter *filter = [[MTHNetworkTransactionsURLFilter alloc] initWithParamsString:params1];
    XCTAssert(filter.urlStringFilter.length == 0);
    XCTAssert(filter.statusFilter == MTHNetworkTransactionStatusCodeNone);
    XCTAssert(filter.duplicateModeFilter == YES);
}

- (void)test_d2 {
    NSString *params1 = @" d";
    MTHNetworkTransactionsURLFilter *filter = [[MTHNetworkTransactionsURLFilter alloc] initWithParamsString:params1];
    XCTAssert(filter.urlStringFilter.length == 0);
    XCTAssert(filter.statusFilter == MTHNetworkTransactionStatusCodeNone);
    XCTAssert(filter.duplicateModeFilter == YES);
}

- (void)test_d3 {
    NSString *params1 = @"d";
    MTHNetworkTransactionsURLFilter *filter = [[MTHNetworkTransactionsURLFilter alloc] initWithParamsString:params1];
    XCTAssert([filter.urlStringFilter isEqualToString:@"d"]);
    XCTAssert(filter.duplicateModeFilter == NO);
}

- (void)test_s0 {
    NSString *params1 = @"s";
    MTHNetworkTransactionsURLFilter *filter = [[MTHNetworkTransactionsURLFilter alloc] initWithParamsString:params1];
    XCTAssert([filter.urlStringFilter isEqualToString:@"s"]);
    XCTAssert(filter.statusFilter == MTHNetworkTransactionStatusCodeNone);
}

- (void)test_s_f {
    NSString *params1 = @"s F";
    MTHNetworkTransactionsURLFilter *filter = [[MTHNetworkTransactionsURLFilter alloc] initWithParamsString:params1];
    XCTAssert(filter.urlStringFilter.length == 0);
    XCTAssert(filter.statusFilter == MTHNetworkTransactionStatusCodeFailed);
}

- (void)test_s_xx {
    [self assertWithStatusRawParams:@[ @"s 1", @"s 10000" ] expectStatus:MTHNetworkTransactionStatusCode1xx];
    [self assertWithStatusRawParams:@[ @"s 2", @"s 222" ] expectStatus:MTHNetworkTransactionStatusCode2xx];
    [self assertWithStatusRawParams:@[ @"s 3", @"s 39" ] expectStatus:MTHNetworkTransactionStatusCode3xx];
    [self assertWithStatusRawParams:@[ @"s 4", @"s 404" ] expectStatus:MTHNetworkTransactionStatusCode4xx];
    [self assertWithStatusRawParams:@[ @"s 5", @"s 5xx" ] expectStatus:MTHNetworkTransactionStatusCode5xx];
    [self assertWithStatusRawParams:@[ @"s 0", @"s 6", @"s a" ] expectStatus:MTHNetworkTransactionStatusCodeNone];
    [self assertWithStatusRawParams:@[ @"ss 4", @"s0 404" ] expectStatus:MTHNetworkTransactionStatusCodeNone];
}

- (void)assertWithStatusRawParams:(NSArray *)paramsList expectStatus:(MTHNetworkTransactionStatusCode)statusFilter {
    for (NSString *params in paramsList) {
        MTHNetworkTransactionsURLFilter *filter = [[MTHNetworkTransactionsURLFilter alloc] initWithParamsString:params];
        XCTAssert(filter.statusFilter == statusFilter);
    }
}

- (void)test_s_xx_url {
    NSString *params1 = @"s 404 meitu.com";
    MTHNetworkTransactionsURLFilter *filter1 = [[MTHNetworkTransactionsURLFilter alloc] initWithParamsString:params1];
    XCTAssert(filter1.statusFilter == MTHNetworkTransactionStatusCode4xx);
    XCTAssert([filter1.urlStringFilter isEqualToString:@"meitu.com"]);

    NSString *params2 = @"meitu.com  s 404";
    MTHNetworkTransactionsURLFilter *filter2 = [[MTHNetworkTransactionsURLFilter alloc] initWithParamsString:params2];
    XCTAssert(filter2.statusFilter == MTHNetworkTransactionStatusCode4xx);
    XCTAssert([filter2.urlStringFilter isEqualToString:@"meitu.com"]);

    NSString *params3 = @"meitu.com ss 404";
    MTHNetworkTransactionsURLFilter *filter3 = [[MTHNetworkTransactionsURLFilter alloc] initWithParamsString:params3];
    XCTAssert([filter3.urlStringFilter isEqualToString:@"404"]);
}

@end

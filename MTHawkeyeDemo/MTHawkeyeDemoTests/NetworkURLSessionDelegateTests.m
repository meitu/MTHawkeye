//
//  NetworkURLSessionDelegateTests.m
//  MTHawkeyeDemoTests
//
//  Created by EuanC on 29/08/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper/AGAsyncTestHelper.h>
#import <GYHttpMock/GYHttpMock.h>

#import <MTHawkeye/MTHNetworkObserver.h>

// MARK: - NetworkObserver
@interface MTHNetworkObserver (ForTest)

+ (instancetype)sharedObserver;
+ (void)injectIntoAllNSURLConnectionDelegateClass;

@end

@interface NetworkURLSessionDelegateTests : XCTestCase <NSURLSessionDelegate>

@property (nonatomic, copy) NSString *urlForNormalRequest;
@property (nonatomic, copy) NSString *urlForFailedRequest;

@end

@implementation NetworkURLSessionDelegateTests

- (void)setUp {
    [super setUp];

    [MTHNetworkObserver injectIntoAllNSURLConnectionDelegateClass];

    self.urlForFailedRequest = @"http://www.gggggg.com";
    self.urlForNormalRequest = @"http://www.google.com";

    // return 200 and a empty body
    mockRequest(@"GET", self.urlForNormalRequest);

    // return 404 failed
    mockRequest(@"GET", self.urlForFailedRequest).andReturn(404);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)test1 {
    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:nil];
    NSURLSessionTask *task = [session dataTaskWithURL:[NSURL URLWithString:self.urlForNormalRequest]];
    [task resume];
}

@end

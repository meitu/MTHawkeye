//
//  NetworkURLConnectionDelegateTests.m
//  MTHawkeyeDemoTests
//
//  Created by EuanC on 28/08/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <AGAsyncTestHelper/AGAsyncTestHelper.h>
#import <GYHttpMock/GYHttpMock.h>

#import <MTHawkeye/MTHNetworkObserver.h>

// MARK: - fake delegates
@interface URLConnectionDelegateHandler1 : NSObject <NSURLConnectionDataDelegate>
@property (nonatomic, assign) BOOL didFinishedLoading;
@end

@implementation URLConnectionDelegateHandler1
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    self.didFinishedLoading = YES;
}
@end

@interface URLConnectionDelegateHandler2 : NSObject <NSURLConnectionDataDelegate>
@property (nonatomic, assign) BOOL didFailedLoading;
@end

@implementation URLConnectionDelegateHandler2
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.didFailedLoading = YES;
}
@end

// MARK: - NetworkObserver
@interface MTHNetworkObserver (ForTest)

+ (instancetype)sharedObserver;
+ (void)injectIntoAllNSURLConnectionDelegateClass;

@end

// MARK: -

@interface NetworkURLConnectionDelegateTests : XCTestCase

@property (nonatomic, copy) NSString *urlForNormalRequest;
@property (nonatomic, copy) NSString *urlForFailedRequest;

@property (nonatomic, strong) URLConnectionDelegateHandler1 *delegateHandler1;
@property (nonatomic, strong) URLConnectionDelegateHandler2 *delegateHandler2;

@end

@implementation NetworkURLConnectionDelegateTests

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
    self.delegateHandler1 = [[URLConnectionDelegateHandler1 alloc] init];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:self.urlForNormalRequest]];
    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self.delegateHandler1];
    [conn start];
}

- (void)test2 {
    self.delegateHandler2 = [[URLConnectionDelegateHandler2 alloc] init];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:self.urlForFailedRequest]];
    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self.delegateHandler2 startImmediately:NO];
    [conn start];
}

- (void)test3 {
    self.delegateHandler1 = [[URLConnectionDelegateHandler1 alloc] init];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:self.urlForNormalRequest]];
    NSURLConnection *conn = [NSURLConnection connectionWithRequest:request delegate:self.delegateHandler1];
    [conn start];
}

@end

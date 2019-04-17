//
//  MTHawkeyeClientTests.m
//  MTHawkeyeDemoTests
//
//  Created by EuanC on 2019/2/1.
//  Copyright © 2019 Meitu. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <MTHawkeye/MTHawkeyeClient.h>
#import <MTHawkeye/MTHawkeyePlugin.h>
#import <MTHawkeye/MTHawkeyeUserDefaults.h>

#import <AGAsyncTestHelper/AGAsyncTestHelper.h>


@interface HawkeyePluginA : NSObject <MTHawkeyePlugin>
@property (nonatomic, assign) BOOL didStartFired;
@property (nonatomic, assign) BOOL didStopFired;
@end

@implementation HawkeyePluginA
+ (NSString *)pluginID {
    return @"A";
}
- (void)hawkeyeClientDidStart {
    self.didStartFired = YES;
    self.didStopFired = NO;
}
- (void)hawkeyeClientDidStop {
    self.didStopFired = YES;
    self.didStartFired = NO;
}
@end

@interface HawkeyePluginB : NSObject <MTHawkeyePlugin>
@property (nonatomic, assign) BOOL didStartFired;
@property (nonatomic, assign) BOOL didStopFired;
@end

@implementation HawkeyePluginB
+ (NSString *)pluginID {
    return @"B";
}
- (void)hawkeyeClientDidStart {
    self.didStartFired = YES;
    self.didStopFired = NO;
}
- (void)hawkeyeClientDidStop {
    self.didStopFired = YES;
    self.didStartFired = NO;
}
@end


/****************************************************************************/
#pragma mark -


@interface MTHawkeyeClientTests : XCTestCase

@property (nonatomic, strong) MTHawkeyeClient *client;

@property (nonatomic, assign) BOOL cacheHawkeyeOnSetting;

@end

@implementation MTHawkeyeClientTests

- (void)setUp {
    _client = [[MTHawkeyeClient alloc] init];

    self.cacheHawkeyeOnSetting = [MTHawkeyeUserDefaults shared].hawkeyeOn;
}

- (void)tearDown {
    _client = nil;

    [MTHawkeyeUserDefaults shared].hawkeyeOn = self.cacheHawkeyeOnSetting;
}

- (void)testAddPlugin {
    HawkeyePluginA *a = [HawkeyePluginA new];
    HawkeyePluginB *b = [HawkeyePluginB new];
    [self.client addPlugin:a];
    [self.client addPlugin:b];

    [self.client startServer];

    AGWW_WAIT_WHILE(a.didStartFired == NO && b.didStartFired == NO, 1.f, @"");

    [MTHawkeyeUserDefaults shared].hawkeyeOn = NO;

    AGWW_WAIT_WHILE(a.didStopFired == NO && b.didStartFired == NO, 1.f, @"");

    [MTHawkeyeUserDefaults shared].hawkeyeOn = YES;

    AGWW_WAIT_WHILE(a.didStartFired == NO && b.didStartFired == YES, 1.f, @"");
}

- (void)testRemovePlugin {
    HawkeyePluginA *a = [HawkeyePluginA new];
    HawkeyePluginB *b = [HawkeyePluginB new];
    [self.client addPlugin:a];
    [self.client addPlugin:b];
    [self.client removePlugin:b];

    [self.client startServer];

    AGWW_WAIT_WHILE(a.didStartFired == NO, 1.f, @"");
    XCTAssertFalse(b.didStartFired);

    [self.client stopServer];

    [self.client addPlugin:b];
    id<MTHawkeyePlugin> a1 = [self.client pluginFromID:[[a class] pluginID]];
    XCTAssertTrue(a1 != nil);
    [self.client removePlugin:a1];

    id<MTHawkeyePlugin> a2 = [self.client pluginFromID:[[a class] pluginID]];
    XCTAssertTrue(a2 == nil);

    [MTHawkeyeUserDefaults shared].hawkeyeOn = NO;
    [MTHawkeyeUserDefaults shared].hawkeyeOn = YES;

    AGWW_WAIT_WHILE(b.didStartFired == NO, 1.f, @"");
    XCTAssertTrue(b.didStartFired);
    XCTAssertFalse(a.didStartFired);
}

@end

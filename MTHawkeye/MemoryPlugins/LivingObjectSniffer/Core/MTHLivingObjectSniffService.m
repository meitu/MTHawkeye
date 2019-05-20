//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/6
// Created by: EuanC
//


#import "MTHLivingObjectSniffService.h"
#import "UIView+MTHLivingObjectSniffer.h"
#import "UIViewController+MTHLivingObjectSniffer.h"

@interface MTHLivingObjectSniffService ()

@property (nonatomic, strong, readwrite) MTHLivingObjectSniffer *sniffer;
@property (nonatomic, assign) BOOL isRunning;
@end


@implementation MTHLivingObjectSniffService

+ (instancetype)shared {
    static MTHLivingObjectSniffService *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });

    return _sharedInstance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _delaySniffInSeconds = 3.f;
    }
    return self;
}

- (void)start {
    self.isRunning = YES;

    [UIViewController mthl_livingObjectSnifferSetup];
    [UIView mthl_livingObjectSnifferSetup];
}

- (void)stop {
    self.isRunning = NO;
}

- (void)addIgnoreList:(NSArray<NSString *> *)ignoreList {
    [self.sniffer.ignoreList addObjectsFromArray:ignoreList];
}

// MAKR: - getter
- (MTHLivingObjectSniffer *)sniffer {
    if (_sniffer == nil) {
        _sniffer = [[MTHLivingObjectSniffer alloc] init];
    }
    return _sniffer;
}

@end

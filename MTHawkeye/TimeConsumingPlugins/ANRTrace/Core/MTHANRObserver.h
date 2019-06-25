//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2017/7/3
// Created by: YWH
//


#import <Foundation/Foundation.h>

@class MTHANRObserver;
@class MTHANRRecord;

typedef void (^MTHANRObserveResultHandler)(MTHANRObserver *anrMonitor, MTHANRRecord *anrRecord);

@interface MTHANRObserver : NSObject
@property (nonatomic, assign) BOOL shouldCaptureBackTrace;
@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, assign, readonly) double anrThresholdInSeconds;
@property (nonatomic, copy, readonly) MTHANRObserveResultHandler monitorBlock;

- (instancetype)initWithObserveResultHandler:(MTHANRObserveResultHandler)monitorBlock;
- (void)startWithANRThreshold:(float)thresholdInSeconds;
- (void)stop;
@end

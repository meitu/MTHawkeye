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
@class MTHANRRecordRaw;

typedef void (^MTHANRObserveResultHandler)(MTHANRObserver *anrMonitor, NSArray<MTHANRRecordRaw *> *detectedANRRecord);


@interface MTHANRObserver : NSObject

@property (nonatomic, assign, readonly) BOOL isRunning;

@property (nonatomic, assign) BOOL shouldCaptureBackTrace;

// 卡顿侦测阈值，默认为 0.1s
@property (nonatomic, assign, readonly) double thresholdInSeconds;

@property (nonatomic, copy, readonly) MTHANRObserveResultHandler monitorBlock;

- (instancetype)initWithObserveResultHandler:(MTHANRObserveResultHandler)monitorBlock;

- (void)startWithThresholdInSeconds:(double)thresholdInSeconds;
- (void)stop;

@end

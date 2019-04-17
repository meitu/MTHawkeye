//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 30/09/2017
// Created by: EuanC
//


#import <Foundation/Foundation.h>

@class MTHANRRecordRaw;
@protocol MTHANRTraceDelegate;

@interface MTHANRTrace : NSObject

// 主线程卡顿侦测阈值，默认为 0.4s
@property (nonatomic, assign) CGFloat thresholdInSeconds;

/// 是否在检测到卡顿的时候抓取堆栈信息
@property (nonatomic, assign) BOOL shouldCaptureBackTrace;

+ (instancetype)shared;

- (void)start;
- (void)stop;
- (BOOL)isRunning;

- (void)addDelegate:(id<MTHANRTraceDelegate>)delegate;
- (void)removeDelegate:(id<MTHANRTraceDelegate>)delegate;

@end


@protocol MTHANRTraceDelegate <NSObject>

- (void)mth_anrMonitor:(MTHANRTrace *)anrMonitor didDetectANR:(MTHANRRecordRaw *)anrRecord;

@end

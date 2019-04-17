//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2017/6/29
// Created by: YWH
//


#import <UIKit/UIKit.h>


@protocol MTHFPSTraceDelegate;

@interface MTHFPSTrace : NSObject

@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, assign, readonly) NSInteger fpsValue;

/**
 GPUImageView 渲染 FPS 值，在有 GPUImageView 的页面时有值
 */
@property (nonatomic, assign, readonly) BOOL gpuImageViewFPSEnable;
@property (nonatomic, assign, readonly) BOOL gpuImageViewDisplaying;
@property (nonatomic, assign, readonly) NSInteger gpuImageFPSValue;

+ (instancetype)shared;

- (void)addDelegate:(id<MTHFPSTraceDelegate>)delegate;
- (void)removeDelegate:(id<MTHFPSTraceDelegate>)delegate;

- (void)start;
- (void)stop;

@end


@protocol MTHFPSTraceDelegate <NSObject>

@required
- (void)fpsValueDidChanged:(NSInteger)FPSValue;

@optional
- (void)gpuImageDisplayingChanged:(BOOL)isDisplay;
- (void)gpuImageFPSValueDidChanged:(NSInteger)gpuImageFPSValue;

@end

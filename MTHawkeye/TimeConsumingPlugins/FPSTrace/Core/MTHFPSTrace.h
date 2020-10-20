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

typedef struct {
    Class rendererClass;
    SEL startRenderSEL;
    SEL endRenderSEL;
    SEL renderProcessSEL;
} MTHFPSGLRenderInfo;

@protocol MTHFPSTraceDelegate;

@interface MTHFPSGLRenderCounter : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, assign) BOOL isGPUImageView;
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, assign) NSUInteger fpsValue;

@property (nonatomic, assign) NSUInteger renderCount;
@property (nonatomic, assign) NSUInteger signpostId;
@property (nonatomic, strong) NSValue *lastRenderTime;
@end

@interface MTHFPSTrace : NSObject
/**
 *  detect mainRunloop DisplayLink as fps value
 */
@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, assign, readonly) NSInteger fpsValue;

/**
 *  we use GPUImageView as GLES renderer in default
 */
@property (nonatomic, assign, readonly) BOOL gpuImageViewFPSEnable;

+ (instancetype)shared;

/**
 *  Registter GLES render process with render porcess info
 *
 *  @param  renderInfo   render view class and render process functions
 *
 *  @dicussion
 *  You can register yourself GLES render view before start call,
 *  assume render view start displaying when startRenderSEL call,
 *  assume render view end displaying when endRenderSEL call,
 *  caculate gl-fps count when renderProcessSEL call
 */
+ (void)registerGLESRenderInfo:(MTHFPSGLRenderInfo)renderInfo;
+ (void)registerGLESClass:(Class)rendererClass;

- (void)addDelegate:(id<MTHFPSTraceDelegate>)delegate;
- (void)removeDelegate:(id<MTHFPSTraceDelegate>)delegate;
- (void)start;
- (void)stop;

- (void)glesRenderer:(id)renderer start:(BOOL)start;
- (void)glesRenderProcess:(id)renderer;
@end

@protocol MTHFPSTraceDelegate <NSObject>
@required
- (void)fpsValueDidChanged:(NSInteger)FPSValue;

@optional
- (void)glRenderCounterValueChange:(MTHFPSGLRenderCounter *)renderCounter;
@end

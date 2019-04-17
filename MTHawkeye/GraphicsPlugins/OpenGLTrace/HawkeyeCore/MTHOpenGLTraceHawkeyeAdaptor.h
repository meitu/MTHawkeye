//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/20
// Created by: EuanC
//


#import <Foundation/Foundation.h>
#import "MTHawkeyePlugin.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MTHOpenGLTraceDelegate;

@interface MTHOpenGLTraceHawkeyeAdaptor : NSObject <MTHawkeyePlugin>

@property (readonly) NSArray *alivingMemoryGLObjects; // Current gl objects in memory
@property (class, readonly) size_t openGLESResourceMemorySize;

- (void)addDelegate:(id<MTHOpenGLTraceDelegate>)delegate;
- (void)removeDelegate:(id<MTHOpenGLTraceDelegate>)delegate;

@end


@protocol MTHOpenGLTraceDelegate <NSObject>

@optional
- (void)glTracer:(MTHOpenGLTraceHawkeyeAdaptor *)gltracer didUpdateMemoryUsed:(size_t)memorySizeInByte;
- (void)glTracerDidUpdateAliveGLObjects:(MTHOpenGLTraceHawkeyeAdaptor *)gltracer;

- (void)glTracer:(MTHOpenGLTraceHawkeyeAdaptor *)gltracer didReceivedErrorMsg:(NSString *)errorMessage;

@end

NS_ASSUME_NONNULL_END

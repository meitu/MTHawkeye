//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/22
// Created by: EuanC
//


#import "MTHawkeyeUserDefaults.h"

NS_ASSUME_NONNULL_BEGIN

@interface MTHawkeyeUserDefaults (OpenGLTrace)

/**
 GLTrace Switch. If YES, Hook GLFunctions, otherwise do nothing.
 */
@property (nonatomic, assign) BOOL openGLTraceOn;

/**
 Default NO. Only dectect and calculate GL Resources(Texture, Framebuffer, Buffer...) Size. If YES, OpenGLTrace will do analyse GLFunction invoked (Check current context exist, GLGetError, Four-Type-Wrong-Using...) [opengl-debugger.md see more]
 */
@property (nonatomic, assign) BOOL openGLTraceAnalysisOn;

/**
 Default NO, when openGLTraceAnalysisOn is set on, change to YES default. If some error occur, OpenGLTrace will throw exception in Hawkeye. Otherwise you should implement MTHOpenGLTraceDelegate protocal to process GL error.
 */
@property (nonatomic, assign) BOOL openGLTraceRaiseExceptionOn;

/**
 Default state depends on openGLTraceOn.
 */
@property (nonatomic, assign) BOOL openGLTraceShowGPUMemoryOn;

@end

NS_ASSUME_NONNULL_END

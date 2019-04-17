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


#import "MTHawkeyeUserDefaults+OpenGLTrace.h"

@implementation MTHawkeyeUserDefaults (OpenGLTrace)

- (BOOL)openGLTraceOn {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(openGLTraceOn))];
    return value ? value.boolValue : NO;
}

- (void)setOpenGLTraceOn:(BOOL)openGLTraceOn {
    [self setObject:@(openGLTraceOn) forKey:NSStringFromSelector(@selector(openGLTraceOn))];
    if ([self openGLTraceAnalysisOn]) {
        [self setOpenGLTraceAnalysisOn:NO];
    }
    if ([self openGLTraceRaiseExceptionOn]) {
        [self setOpenGLTraceRaiseExceptionOn:NO];
    }
}

- (BOOL)openGLTraceAnalysisOn {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(openGLTraceAnalysisOn))];
    return value ? value.boolValue : NO;
}

- (void)setOpenGLTraceAnalysisOn:(BOOL)openGLTraceAnalysisOn {
    [self setObject:@(openGLTraceAnalysisOn) forKey:NSStringFromSelector(@selector(openGLTraceAnalysisOn))];
    if ([self openGLTraceAnalysisOn]) {
        [self setOpenGLTraceRaiseExceptionOn:YES];
    }
}

- (BOOL)openGLTraceRaiseExceptionOn {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(openGLTraceRaiseExceptionOn))];
    return value ? value.boolValue : NO;
}

- (void)setOpenGLTraceRaiseExceptionOn:(BOOL)openGLTraceRaiseExceptionOn {
    [self setObject:@(openGLTraceRaiseExceptionOn) forKey:NSStringFromSelector(@selector(openGLTraceRaiseExceptionOn))];
}

- (BOOL)openGLTraceShowGPUMemoryOn {

    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(openGLTraceShowGPUMemoryOn))];
    if (![self openGLTraceOn]) {
        return NO;
    }
    return value ? value.boolValue : YES;
}

- (void)setOpenGLTraceShowGPUMemoryOn:(BOOL)openGLTraceShowGPUMemoryOn {
    [self setObject:@(openGLTraceShowGPUMemoryOn) forKey:NSStringFromSelector(@selector(openGLTraceShowGPUMemoryOn))];
}

@end

//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/21
// Created by: EuanC
//


#import "MTHawkeyeUserDefaults+ObjcCallTrace.h"

@implementation MTHawkeyeUserDefaults (ObjcCallTrace)

- (void)setObjcCallTraceOn:(BOOL)objcCallTraceOn {
    [self setObject:@(objcCallTraceOn) forKey:NSStringFromSelector(@selector(objcCallTraceOn))];
}

- (BOOL)objcCallTraceOn {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(objcCallTraceOn))];
    return value ? value.boolValue : NO;
}

- (void)setObjcCallTraceTimeThresholdInMS:(CGFloat)objcCallTraceTimeThresholdInMS {
    [self setObject:@(objcCallTraceTimeThresholdInMS) forKey:NSStringFromSelector(@selector(objcCallTraceTimeThresholdInMS))];
}

- (CGFloat)objcCallTraceTimeThresholdInMS {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(objcCallTraceTimeThresholdInMS))];
    return value ? value.floatValue : 10.f;
}

- (void)setObjcCallTraceDepthLimit:(NSInteger)objcCallTraceDepthLimit {
    [self setObject:@(objcCallTraceDepthLimit) forKey:NSStringFromSelector(@selector(objcCallTraceDepthLimit))];
}

- (NSInteger)objcCallTraceDepthLimit {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(objcCallTraceDepthLimit))];
    return value ? value.integerValue : 5;
}

@end

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


#import "MTHawkeyeUserDefaults+ANRMonitor.h"

@implementation MTHawkeyeUserDefaults (ANRMonitor)

- (BOOL)anrTraceOn {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(anrTraceOn))];
    return value ? value.boolValue : YES;
}

- (void)setAnrTraceOn:(BOOL)anrTraceOn {
    [self setObject:@(anrTraceOn) forKey:NSStringFromSelector(@selector(anrTraceOn))];
}

- (CGFloat)anrThresholdInSeconds {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(anrThresholdInSeconds))];
    return value ? value.floatValue : 0.4f;
}

- (void)setAnrThresholdInSeconds:(CGFloat)anrThresholdInSeconds {
    [self setObject:@(anrThresholdInSeconds) forKey:NSStringFromSelector(@selector(anrThresholdInSeconds))];
}

- (CGFloat)anrDetectInterval {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(anrDetectInterval))];
    return value ? value.floatValue : 0.1f;
}

- (void)setAnrDetectInterval:(CGFloat)anrDetectInterval {
    [self setObject:@(anrDetectInterval) forKey:NSStringFromSelector(@selector(anrDetectInterval))];
}
@end

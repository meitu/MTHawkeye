//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/17
// Created by: EuanC
//


#import "MTHawkeyeUserDefaults+LivingObjectsSniffer.h"

@implementation MTHawkeyeUserDefaults (LivingObjectsSniffer)

- (void)setLivingObjectsSnifferOn:(BOOL)livingObjectsSnifferOn {
    [self setObject:@(livingObjectsSnifferOn) forKey:NSStringFromSelector(@selector(livingObjectsSnifferOn))];
}

- (BOOL)livingObjectsSnifferOn {
    NSNumber *on = [self objectForKey:NSStringFromSelector(@selector(livingObjectsSnifferOn))];
    return on ? on.boolValue : YES;
}

- (void)setLivingObjectsSnifferContainerSniffEnabled:(BOOL)livingObjectsSnifferContainerSniffEnabled {
    [self setObject:@(livingObjectsSnifferContainerSniffEnabled) forKey:NSStringFromSelector(@selector(livingObjectsSnifferContainerSniffEnabled))];
}

- (BOOL)livingObjectsSnifferContainerSniffEnabled {
    NSNumber *on = [self objectForKey:NSStringFromSelector(@selector(livingObjectsSnifferContainerSniffEnabled))];
    return on ? on.boolValue : NO;
}

- (void)setLivingObjectSnifferTaskDelayInSeconds:(CGFloat)delaySniffInSeconds {
    [self setObject:@(delaySniffInSeconds) forKey:NSStringFromSelector(@selector(livingObjectSnifferTaskDelayInSeconds))];
}

- (CGFloat)livingObjectSnifferTaskDelayInSeconds {
    NSNumber *seconds = [self objectForKey:NSStringFromSelector(@selector(livingObjectSnifferTaskDelayInSeconds))];
    return [seconds floatValue] > 0.f ? [seconds floatValue] : 3.f;
}

@end

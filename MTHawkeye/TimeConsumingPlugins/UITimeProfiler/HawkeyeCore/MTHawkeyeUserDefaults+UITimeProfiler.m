//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/24
// Created by: EuanC
//


#import "MTHawkeyeUserDefaults+UITimeProfiler.h"

@implementation MTHawkeyeUserDefaults (UITimeProfiler)

- (void)setVcLifeTraceOn:(BOOL)vcLifeTraceOn {
    [self setObject:@(vcLifeTraceOn) forKey:NSStringFromSelector(@selector(vcLifeTraceOn))];
}

- (BOOL)vcLifeTraceOn {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(vcLifeTraceOn))];
    return value ? value.boolValue : YES;
}

@end

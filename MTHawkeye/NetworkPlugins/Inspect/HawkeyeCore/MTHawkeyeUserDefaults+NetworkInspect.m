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


#import "MTHawkeyeUserDefaults+NetworkInspect.h"

@implementation MTHawkeyeUserDefaults (NetworkInspect)

- (void)setNetworkInspectOn:(BOOL)networkInspectOn {
    [self setObject:@(networkInspectOn) forKey:NSStringFromSelector(@selector(networkInspectOn))];
}

- (BOOL)networkInspectOn {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(networkInspectOn))];
    return value ? value.boolValue : YES;
}

@end

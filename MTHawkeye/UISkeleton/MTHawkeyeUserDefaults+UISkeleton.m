//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/16
// Created by: EuanC
//


#import "MTHawkeyeUserDefaults+UISkeleton.h"

@implementation MTHawkeyeUserDefaults (UISkeleton)

- (void)setDisplayFloatingWindow:(BOOL)display {
    [self setObject:@(display) forKey:NSStringFromSelector(@selector(displayFloatingWindow))];
}

- (BOOL)displayFloatingWindow {
    NSNumber *display = [self objectForKey:NSStringFromSelector(@selector(displayFloatingWindow))];
    return display ? display.boolValue : YES;
}

- (void)setFloatingWindowShowHideGesture:(BOOL)floatingWindowShowHideGesture {
    [self setObject:@(floatingWindowShowHideGesture) forKey:NSStringFromSelector(@selector(floatingWindowShowHideGesture))];
}

- (BOOL)floatingWindowShowHideGesture {
    NSNumber *gesture = [self objectForKey:NSStringFromSelector(@selector(floatingWindowShowHideGesture))];
    return gesture ? gesture.boolValue : YES;
}

@end

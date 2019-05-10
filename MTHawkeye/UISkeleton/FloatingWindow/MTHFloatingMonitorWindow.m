//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 30/06/2017
// Created by: EuanC
//


#import "MTHFloatingMonitorWindow.h"


@interface MTHFloatingMonitorWindow ()

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

@end


@implementation MTHFloatingMonitorWindow

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [super initWithCoder:aDecoder];
}

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController {
    if (self = [super initWithFrame:[UIScreen mainScreen].bounds]) {
        self.backgroundColor = [UIColor clearColor];
        self.windowLevel = UIWindowLevelStatusBar - 1;
        self.rootViewController = rootViewController;
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    BOOL ptInside = NO;
    if ([self.eventDelegate shouldPointBeHandled:point]) {
        ptInside = [super pointInside:point withEvent:event];
    }
    return ptInside;
}

// MARK: - Private API
// Only when the main panels display, we take control the status bar appearance.
- (BOOL)_canAffectStatusBarAppearance {
    return [self isKeyWindow];
}

- (BOOL)_canBecomeKeyWindow {
    return [self.eventDelegate canBecomeKeyWindow];
}

@end

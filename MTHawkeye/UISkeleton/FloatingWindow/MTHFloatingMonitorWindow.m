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

#define DegreesToRadians(degrees) ((degrees)*M_PI / 180.)

static int _originDegrees = 0;

@interface MTHFloatingMonitorWindow ()

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

@end

@implementation MTHFloatingMonitorWindow

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [super initWithCoder:aDecoder];
}

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController {
    if (self = [super initWithFrame:[UIScreen mainScreen].bounds]) {
        self.backgroundColor = [UIColor clearColor];
        self.windowLevel = UIWindowLevelStatusBar - 1;
        self.rootViewController = rootViewController;

        UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
        switch (orientation) {
            case UIInterfaceOrientationLandscapeLeft:
                _originDegrees = -90;
                break;
            case UIInterfaceOrientationLandscapeRight:
                _originDegrees = 90;
                break;
            case UIInterfaceOrientationPortraitUpsideDown:
                _originDegrees = 180;
                break;
            case UIInterfaceOrientationPortrait:
            default:
                _originDegrees = 0;
                break;
        }

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(statusBarDidChangeFrame:)
                                                     name:UIApplicationDidChangeStatusBarFrameNotification
                                                   object:nil];
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return [self.delegate shouldPointBeHandled:point];
}

- (CGAffineTransform)transformForOrientation:(UIInterfaceOrientation)orientation {

    double rotateRadian = 0;
    switch (orientation) {
        case UIInterfaceOrientationLandscapeLeft:
            rotateRadian = DegreesToRadians(-90 - _originDegrees);
            break;
        case UIInterfaceOrientationLandscapeRight:
            rotateRadian = DegreesToRadians(90 - _originDegrees);
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            rotateRadian = DegreesToRadians(180 - _originDegrees);
            break;
        case UIInterfaceOrientationPortrait:
        default:
            rotateRadian = DegreesToRadians(0 - _originDegrees);
            break;
    }

    return CGAffineTransformMakeRotation(rotateRadian);
}

- (void)statusBarDidChangeFrame:(NSNotification *)notification {
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];

    // 把内容扭转过去
    CGAffineTransform contentTransform = [self transformForOrientation:orientation];
    [self setTransform:contentTransform];

    // 把 frame 扭转回来
    CGRect windowFrame = [UIScreen mainScreen].bounds;
    windowFrame = CGRectApplyAffineTransform(windowFrame, contentTransform);
    windowFrame.origin = CGPointZero;
    self.frame = windowFrame;
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

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


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MTHFloatingMonitorWindowDelegate;


@interface MTHFloatingMonitorWindow : UIWindow

@property (weak, nonatomic) id<MTHFloatingMonitorWindowDelegate> eventDelegate;

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder;

@end


@protocol MTHFloatingMonitorWindowDelegate

@required
- (BOOL)shouldPointBeHandled:(CGPoint)point;
- (BOOL)canBecomeKeyWindow;

@end


NS_ASSUME_NONNULL_END

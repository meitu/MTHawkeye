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


#import <Foundation/Foundation.h>
#import <MTHawkeye/MTHawkeyeUIPlugin.h>

NS_ASSUME_NONNULL_BEGIN

@class MTHawkeyeSettingSectionEntity;

@interface MTHOpenGLTraceHawkeyeUI : NSObject <MTHawkeyeSettingUIPlugin, MTHawkeyeMainPanelPlugin, MTHawkeyeFloatingWidgetPlugin>

@property (nonatomic, assign) BOOL widgetHidden;

@end

NS_ASSUME_NONNULL_END

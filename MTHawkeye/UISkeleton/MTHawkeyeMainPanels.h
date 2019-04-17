//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/9
// Created by: EuanC
//


#import <Foundation/Foundation.h>
#import "MTHawkeyeMainPanelSwitchViewController.h"
#import "MTHawkeyeMainPanelViewController.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MTHawkeyeMainPanelPlugin;
@protocol MTHawkeyeMainPanelSwitcherDelegate;

@interface MTHawkeyeMainPanels : NSObject <MTHawkeyeMainPanelViewControllerDatasource, MTHawkeyeMainPanelSwitcherDelegate>

@property (readonly) NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *panels;

- (instancetype)initWithMainPanelPlugins:(NSArray<id<MTHawkeyeMainPanelPlugin>> *)plugins;
- (void)addMainPanelPlugin:(id<MTHawkeyeMainPanelPlugin>)plugin;
- (void)removeMainPanelPlugin:(id<MTHawkeyeMainPanelPlugin>)plugin;

@end

NS_ASSUME_NONNULL_END

//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/14
// Created by: EuanC
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MTHawkeyeSettingUIPlugin;
@protocol MTHawkeyeFloatingWidgetDisplaySwitcherPlugin;
@class MTHawkeyeSettingTableEntity;
@class MTHawkeyeSettingFoldedCellEntity;

@interface MTHawkeyeSettingUIEntity : NSObject

@property (readonly) NSMutableArray<id<MTHawkeyeSettingUIPlugin>> *plugins;
@property (readonly) NSMutableArray<id<MTHawkeyeFloatingWidgetDisplaySwitcherPlugin>> *floatingWidgetCells;

- (instancetype)initWithSettingPlugins:(NSArray<id<MTHawkeyeSettingUIPlugin>> *)settingPlugins
               floatingWidgetSwitchers:(NSArray<id<MTHawkeyeFloatingWidgetDisplaySwitcherPlugin>> *)floatingWidgetSwitchers;

- (void)addSettingPlugin:(id<MTHawkeyeSettingUIPlugin>)plugin;
- (void)removeSettingPlugin:(id<MTHawkeyeSettingUIPlugin>)plugin;
- (void)removeAllSettingPlugins;

- (void)addFloatingWidgetSwitcher:(id<MTHawkeyeFloatingWidgetDisplaySwitcherPlugin>)plugin;
- (void)removeFloatingWidgetSwitcher:(id<MTHawkeyeFloatingWidgetDisplaySwitcherPlugin>)plugin;
- (void)removeAllFloatingWidget;

- (MTHawkeyeSettingTableEntity *)settingViewModelEntity;

@end

NS_ASSUME_NONNULL_END

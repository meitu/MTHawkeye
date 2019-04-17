//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 16/11/2017
// Created by: EuanC
//


#import <Foundation/Foundation.h>

#import <MTHawkeye/MTHawkeyeClient.h>
#import <MTHawkeye/MTHawkeyeUIClient.h>


@interface MTHawkeyeDefaultPlugins : NSObject

+ (void)loadEarlyServices;

+ (void)addDefaultClientPluginsInto:(NSMutableArray<id<MTHawkeyePlugin>> *)clientPlugins;
+ (void)cleanDefaultClientPluginsFrom:(NSMutableArray<id<MTHawkeyePlugin>> *)clientPlugins;

+ (void)addDefaultUIClientMainPanelPluginsInto:(NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *)mainPanelPlugins
             defaultFloatingWidgetsPluginsInto:(NSMutableArray<id<MTHawkeyeFloatingWidgetPlugin>> *)floatingWidgetPlugins
                   defaultSettingUIPluginsInto:(NSMutableArray<id<MTHawkeyeSettingUIPlugin>> *)settingUIPlugins;

+ (void)cleanDefaultUIClientMainPanelPluginsFrom:(NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *)mainPanelPlugins
               defaultFloatingWidgetsPluginsFrom:(NSMutableArray<id<MTHawkeyeFloatingWidgetPlugin>> *)floatingWidgetPlugins
                     defaultSettingUIPluginsFrom:(NSMutableArray<id<MTHawkeyeSettingUIPlugin>> *)settingUIPlugins;

@end

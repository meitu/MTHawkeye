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


#import "MTRunHawkeyeInOneLine.h"
#import "MTHawkeyeClient.h"
#import "MTHawkeyeDefaultPlugins.h"
#import "MTHawkeyeUIClient.h"


@implementation MTRunHawkeyeInOneLine

+ (void)start {
    [[MTHawkeyeClient shared]
        setPluginsSetupHandler:^(NSMutableArray<id<MTHawkeyePlugin>> *_Nonnull plugins) {
            [MTHawkeyeDefaultPlugins addDefaultClientPluginsInto:plugins];

            // add your additional plugins here.
        }
        pluginsCleanHandler:^(NSMutableArray<id<MTHawkeyePlugin>> *_Nonnull plugins) {
            // if you don't want to free plugins memory, remove this line.
            [MTHawkeyeDefaultPlugins cleanDefaultClientPluginsFrom:plugins];

            // clean your additional plugins if need.
        }];

    [[MTHawkeyeClient shared] startServer];

    [[MTHawkeyeUIClient shared]
        setPluginsSetupHandler:^(NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *_Nonnull mainPanelPlugins, NSMutableArray<id<MTHawkeyeFloatingWidgetPlugin>> *_Nonnull floatingWidgetPlugins, NSMutableArray<id<MTHawkeyeSettingUIPlugin>> *_Nonnull defaultSettingUIPluginsInto) {
            [MTHawkeyeDefaultPlugins addDefaultUIClientMainPanelPluginsInto:mainPanelPlugins
                                          defaultFloatingWidgetsPluginsInto:floatingWidgetPlugins
                                                defaultSettingUIPluginsInto:defaultSettingUIPluginsInto];

            // add your additional plugins here.
        }
        pluginsCleanHandler:^(NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *_Nonnull mainPanelPlugins, NSMutableArray<id<MTHawkeyeFloatingWidgetPlugin>> *_Nonnull floatingWidgetPlugins, NSMutableArray<id<MTHawkeyeSettingUIPlugin>> *_Nonnull defaultSettingUIPluginsInto) {
            // if you don't want to free plugins memory, remove this line.
            [MTHawkeyeDefaultPlugins cleanDefaultUIClientMainPanelPluginsFrom:mainPanelPlugins
                                            defaultFloatingWidgetsPluginsFrom:floatingWidgetPlugins
                                                  defaultSettingUIPluginsFrom:defaultSettingUIPluginsInto];

            // clean your additional plugins if need.
        }];

    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [[MTHawkeyeUIClient shared] startServer];
    });
}

+ (void)stop {
    [[MTHawkeyeUIClient shared] stopServer];
    [[MTHawkeyeClient shared] stopServer];
}

@end

//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/4
// Created by: EuanC
//


#import <Foundation/Foundation.h>
#import "MTHawkeyeUIPlugin.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^MTHawkeyeUIClientPluginsSetupHandler)(
    NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *mainPanelPluginsToAdd,
    NSMutableArray<id<MTHawkeyeFloatingWidgetPlugin>> *floatingWidgetPluginsToAdd,
    NSMutableArray<id<MTHawkeyeSettingUIPlugin>> *settingUIPluginsIntoToAdd);

typedef void (^MTHawkeyeUIClientPluginsCleanHandler)(
    NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *mainPanelPluginsAdded,
    NSMutableArray<id<MTHawkeyeFloatingWidgetPlugin>> *floatingWidgetPluginsAdded,
    NSMutableArray<id<MTHawkeyeSettingUIPlugin>> *settingUIPluginsIntoAdded);


@interface MTHawkeyeUIClient : NSObject

@property (readonly) MTHawkeyeUIClientPluginsSetupHandler pluginsSetupHandler;
@property (readonly) MTHawkeyeUIClientPluginsCleanHandler pluginsCleanHandler;

+ (instancetype)shared;

/**
 plugins setup and cleaner, should call before `startServer`.

 @param pluginsSetupHandler pluginsSetupHandler will be called while `startServer` invoked.
                            the initial plugin array is empty,
                            after the block, the added plugins will be used to setup client,
                            you can add your own plugins into the array here.

 @param pluginsCleanHandler pluginsCleanHandler will be called while `stopServer` invoked.
                            the plugin array item will be remove internal after stop,
                            you can do cleanup if you've retain the plugins external.
 */
- (void)setPluginsSetupHandler:(MTHawkeyeUIClientPluginsSetupHandler)pluginsSetupHandler
           pluginsCleanHandler:(MTHawkeyeUIClientPluginsCleanHandler)pluginsCleanHandler;

/**
 setup ui plugins and start server, then show floating monitor window if need.

 after the server start, a gesture recognizer will be placed on the keyWindow to show/hide the floating monitor window.
 */
- (void)startServer;

/**
 hide window and stop server, then call the pluginsCleaner do clean stuff.

 the gesture recognizer will remain, if you want to remove the recognizer,
 go to Hawkeye Setting UI, turn off show/hide window gesture recognizer manual.
 */
- (void)stopServer;

/**
 show floating monitor window, you can also show the window by 3 fingers long press for 3 seconds gesture.
 */
- (void)showWindow;

/**
 hide floating monitor window. you can also hide the window by 3 fingers long press for 3 seconds gesture.
 */
- (void)hideWindow;

/**
 Open the main panel with id mainPanelId, which related to `mainPanelIdentity`
 in `MTHawkeyeMainPanelPlugin`.

 when the mainPanelId is nil, will open previous viewed panel.

 @param mainPanelId the panel you want to open, related to `mainPanelIdentity` in `MTHawkeyeMainPanelPlugin`
 */
- (void)showMainPanelWithSelectedID:(nullable NSString *)mainPanelId;

/**
 Find specific floating widget plugin with floatingWidgetID and raise an warning on it.

 You can configure the warning action by passing a params.

 params eg.: raise warning on `mem` floating widget for 5 seconds, and when tap the floating widget
      during the warning, it will jump to "memory-records" panel.

  {
    // flashing the warning for 5 seconds.
    kMTHFloatingWidgetRaiseWarningParamsKeepDurationKey : @(5.f),

    // search `mainPanelIdentity` in `MTHawkeyeMainPanelPlugin`.
    kMTHFloatingWidgetRaiseWarningParamsPanelIDKey : @"memory-records",
  }

 @param floatingWidgetID where warning raise on, related to `widgetIdentity` in `MTHawkeyeFloatingWidgetPlugin`
 @param params key:
            kMTHFloatingWidgetRaiseWarningParamsKeepDurationKey, see above
            kMTHFloatingWidgetRaiseWarningParamsPanelIDKey, see above
 */
- (void)raiseWarningOnFloatingWidget:(NSString *)floatingWidgetID
                          withParams:(nullable NSDictionary *)params;

@end


NS_ASSUME_NONNULL_END

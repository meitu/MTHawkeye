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

NS_ASSUME_NONNULL_BEGIN


/*
 Hawkeye UI Build-in Group name list (for Settings and Main panel).
 */
extern NSString *const kMTHawkeyeUIGroupMemory;        /**< Memory group */
extern NSString *const kMTHawkeyeUIGroupTimeConsuming; /**< TimeConsuming group */
extern NSString *const kMTHawkeyeUIGroupEnergy;        /**< Energy group */
extern NSString *const kMTHawkeyeUIGroupNetwork;       /**< Network group */
extern NSString *const kMTHawkeyeUIGroupGraphics;      /**< Graphics group */
extern NSString *const kMTHawkeyeUIGroupStorage;       /**< Storage group */
extern NSString *const kMTHawkeyeUIGroupUtility;       /**< Utility group */


/****************************************************************************/
#pragma mark - Setting UI Plugin

@protocol MTHawkeyePlugin;
@class MTHawkeyeSettingCellEntity;

/**
 Once you wanna provide a setting UI under Hawkeye user interface. you should
 implement a class that follow `MTHawkeyeSettingUIPlugin` and create an instance
 then add to `MTHawkeyeUIClient` by add to `settingUIPluginsIntoToAdd` array on
 `MTHawkeyeUIClientPluginsSetupHandler`

 see doc `hawkeye-plugin-dev-guide.md` for detail.
 */
@protocol MTHawkeyeSettingUIPlugin <NSObject>

@required

/**
 The section which your setting UI is placed under, you can use built-in group name above.
 */
+ (NSString *)sectionNameSettingsUnder;

/**
 Your setting UI entity, will placed under the specific section.

 Generally, a cell of type `MTHawkeyeSettingFoldedCellEntity` is return from
 `+ (MTHawkeyeSettingCellEntity *)settings`, and the actual settings entity items
 are placed inside the folded cell, with a `DisclosureIndicator` cell style to guide to the detail.

 see `MTHUITimeProfilerHawkeyeUI.m` as an example.

 @return the setting ui entity for your plugin.
 */
+ (MTHawkeyeSettingCellEntity *)settings;

@end


/****************************************************************************/
#pragma mark - Floating Widget Plugin

@class MTHawkeyeSettingSwitcherCellEntity;

@protocol MTHawkeyeFloatingWidgetDisplaySwitcherPlugin <NSObject>

@optional

/**
 Show/Hide switcher setting item for the floating widget.

 @return the switcher setting item.
 */
- (MTHawkeyeSettingSwitcherCellEntity *)floatingWidgetSwitcher;

@end


@class MTHMonitorViewCell;
@protocol MTHawkeyeFloatingWidgetDelegate;

extern const NSString *kMTHFloatingWidgetRaiseWarningParamsKeepDurationKey;
extern const NSString *kMTHFloatingWidgetRaiseWarningParamsPanelIDKey;

/**
 Once you wanna provide a floating widget in Hawkeye floating monitor window, you should
 implement a class that follow `MTHawkeyeFloatingWidgetPlugin` and add an instance to `MTHawkeyeUIClient`.

 If you need a setting UI to show/hide the widget, you should implement `floatingWidgetSwitcher`

 see doc `hawkeye-plugin-dev-guide.md` for detail.
 */
@protocol MTHawkeyeFloatingWidgetPlugin <MTHawkeyeFloatingWidgetDisplaySwitcherPlugin>

@required
@property (nonatomic, weak) id<MTHawkeyeFloatingWidgetDelegate> delegate;

@required
- (NSString *)widgetIdentity;

/**
 The floating window widget create by your plugin.

 see doc `hawkeye-plugin-dev-guide.md` for detail, or `MTHawkeyeMemoryStatFloatingWidget` as an example.
 */
- (MTHMonitorViewCell *)widget;
- (BOOL)widgetHidden;

@optional

/**
 If you need to update the status display regularly, refresh `MTHMonitorViewCell`
 under `- (void)receivedFlushStatusCommand`
 */
- (void)receivedFlushStatusCommand;

/**
 If you want to support warning on `MTHMonitorViewCell`, implement
 `- (void)receivedRaiseWarningCommand:(NSDictionary *)params` and configure your own warning style.

 See `MTFPSHawkeyeUI` as an example
 */
- (void)receivedRaiseWarningCommand:(NSDictionary *)params;

@end

@protocol MTHawkeyeFloatingWidgetDelegate <NSObject>

- (void)floatingWidgetWantHidden:(id<MTHawkeyeFloatingWidgetPlugin>)widget;
- (void)floatingWidgetWantShow:(id<MTHawkeyeFloatingWidgetPlugin>)widget;

@end


/****************************************************************************/
#pragma mark - Main Panel Plugin

/**
 If you wanna add your own module user interface under Hawkeye, you can implement a
 class that follow `MTHawkeyeMainPanelPlugin` and create an instance
 then add to `MTHawkeyeUIClient` by add to `mainPanelPluginsIntoToAdd` array on
 `MTHawkeyeUIClientPluginsSetupHandler`

 see doc `hawkeye-plugin-dev-guide.md` for detail.
 */
@protocol MTHawkeyeMainPanelPlugin <NSObject>

@required

/**
 The entry title of the plugin.

 Once you open the Hawkeye main panel, you can navigate to your panel
 through the plugins switching view, and you should implement
 `switchingOptionTitle` to set a name as the entry of your plugin.
 */
- (NSString *)switchingOptionTitle;

/**
 The group which the plugin belongs on the switcher.

 The switching options was grouped, for build-in groups see `kMTHawkeyeUIGroup***` above.
 */
- (NSString *)groupNameSwitchingOptionUnder;

@optional

/**
 the navigation title when the main panel selected

 optional, if not implemented, use the title returned by `switchingOptionTitle`
 */
- (nullable NSString *)mainPanelTitle;

/**
 The main panel of your plugin, will use as an childViewController under MTHawkeyeUIClient

 When you wanna put your plugin's panel as a child viewController of MainPanelViewController,
 you should implement `mainPanelViewController`.

 @return The main panel of your plugin.
 */
- (UIViewController *)mainPanelViewController;
- (NSString *)mainPanelIdentity;

/**
 When the plugin has a custom main panel like FLEX, You should implement
 the following method and tell the HawkeyeUI trigger custom action, then
 you can do what you want in `switchingOptionDidTapped`

 And when you set to TriggerCustomAction, the swithingOption would not
 keep the selected status.

 See `FLEXHawkeyePlugin` as an example.
 */
- (BOOL)switchingOptionTriggerCustomAction;
- (void)switchingOptionDidTapped;

@end

NS_ASSUME_NONNULL_END

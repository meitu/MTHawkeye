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


#import "MTHawkeyeDefaultPlugins.h"

#import <MTHawkeye/MTFPSHawkeyeAdaptor.h>
#import <MTHawkeye/MTFPSHawkeyeUI.h>
#import <MTHawkeye/MTHawkeyeInnerLogger.h>
#import <MTHawkeye/MTHawkeyeUserDefaults+UISkeleton.h>
#import <MTHawkeye/MTHawkeyeUserDefaults.h>
#import <MTHawkeye/MTHawkeyeUtility.h>

#import <MTHawkeye/MTHANRHawkeyeAdaptor.h>
#import <MTHawkeye/MTHANRHawkeyeUI.h>

#import <MTHawkeye/MTHAppLaunchStepTracer.h>
#import <MTHawkeye/MTHCallTrace.h>
#import <MTHawkeye/MTHObjcCallTraceHawkeyeAdaptor.h>
#import <MTHawkeye/MTHUITimeProfilerHawkeyeAdaptor.h>
#import <MTHawkeye/MTHUITimeProfilerHawkeyeUI.h>
#import <MTHawkeye/MTHUIViewControllerProfile.h>
#import <MTHawkeye/MTHawkeyeUserDefaults+UITimeProfiler.h>

#import <MTHawkeye/MTHCPUTraceHawkeyeAdaptor.h>
#import <MTHawkeye/MTHCPUTraceHawkeyeUI.h>

#import <MTHawkeye/MTHLivingObjectsSnifferHawkeyeAdaptor.h>
#import <MTHawkeye/MTHLivingObjectsSnifferHawkeyeUI.h>

#import <MTHawkeye/MTHAllocationsHawkeyeAdaptor.h>
#import <MTHawkeye/MTHAllocationsHawkeyeUI.h>
#import <MTHawkeye/MTHawkeyeUserDefaults+Allocations.h>

#ifdef MTH_INCLUDE_GLTRACE
#import <MTHawkeye/MTHOpenGLTraceHawkeyeAdaptor.h>
#import <MTHawkeye/MTHOpenGLTraceHawkeyeUI.h>
#endif

#import <MTHawkeye/MTHNetworkHawkeyeUI.h>
#import <MTHawkeye/MTHNetworkInspectHawkeyeAdaptor.h>
#import <MTHawkeye/MTHNetworkMonitor.h>
#import <MTHawkeye/MTHNetworkMonitorHawkeyeAdaptor.h>
#import <MTHawkeye/MTHawkeyeUserDefaults+NetworkMonitor.h>

#import <MTHawkeye/MTHDirectoryWatcherHawkeyeAdaptor.h>
#import <MTHawkeye/MTHDirectoryWatcherHawkeyeUI.h>

#import <MTHawkeye/FLEXHawkeyePlugin.h>


@interface MTHawkeyeDefaultPlugins ()

@end

static NSMutableArray<id<MTHawkeyePlugin>> *defaultClientPlugins;
static NSMutableArray<id<MTHawkeyeSettingUIPlugin>> *defaultdefaultSettingUIPluginsInto;
static NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *defaultMainPanelPlugins;
static NSMutableArray<id<MTHawkeyeFloatingWidgetPlugin>> *defaultdefaultFloatingWidgetsPluginsInto;

@implementation MTHawkeyeDefaultPlugins

+ (void)load {
    [self loadEarlyServices];
}

+ (void)loadEarlyServices {
    if ([MTHawkeyeUtility underUnitTest])
        return;

    if (![MTHawkeyeUserDefaults shared].hawkeyeOn)
        return;

    // services that need to be started before HawkeyeClient start.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // ! under standardUserDefaults not HawkeyeUserDefault
        if ([[NSUserDefaults standardUserDefaults] boolForKey:kHawkeyeCalltraceAutoLaunchKey]) {
            [MTHCallTrace startAtOnce];
        }

#if __has_include(<CocoaLumberjack/CocoaLumberjack.h>)
        [MTHawkeyeInnerLogger setupConsoleLoggerWithLevel:DDLogLevelVerbose];
        [MTHawkeyeInnerLogger setupFileLoggerWithLevel:DDLogLevelVerbose];
#endif

        [MTHAppLaunchStepTracer traceSteps];

        if ([MTHawkeyeUserDefaults shared].vcLifeTraceOn) {
            [MTHUIViewControllerProfile startVCProfile];
        }

        if ([MTHawkeyeUserDefaults shared].allocationsTraceOn) {
            [MTHAllocationsHawkeyeAdaptor startAllocationsTracer];

            if ([MTHawkeyeUserDefaults shared].chunkMallocTraceOn) {
                [MTHAllocationsHawkeyeAdaptor startSingleChunkMallocTracer];
            }
        }

        if ([MTHawkeyeUserDefaults shared].networkMonitorOn) {
            [[MTHNetworkMonitor shared] start];
        }
    });
}

+ (void)initialize {
    defaultClientPlugins = @[].mutableCopy;
    defaultMainPanelPlugins = @[].mutableCopy;
    defaultdefaultSettingUIPluginsInto = @[].mutableCopy;
    defaultdefaultFloatingWidgetsPluginsInto = @[].mutableCopy;
}

// MARK: -
+ (void)addDefaultClientPluginsInto:(NSMutableArray<id<MTHawkeyePlugin>> *)plugins {
    @synchronized(defaultClientPlugins) {
        if (defaultClientPlugins.count == 0)
            [self setupDefaultClientPlugins];

        for (id<MTHawkeyePlugin> plugin in defaultClientPlugins) {
            if (![plugins containsObject:plugin])
                [plugins addObject:plugin];
        }
    }
}

+ (void)cleanDefaultClientPluginsFrom:(NSMutableArray<id<MTHawkeyePlugin>> *)plugins {
    @synchronized(defaultClientPlugins) {
        for (id<MTHawkeyePlugin> plugin in defaultClientPlugins) {
            if ([plugins containsObject:plugin])
                [plugins removeObject:plugin];
        }

        [defaultClientPlugins removeAllObjects];
    }
}

+ (void)addDefaultUIClientMainPanelPluginsInto:(NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *)mainPanelPlugins
             defaultFloatingWidgetsPluginsInto:(NSMutableArray<id<MTHawkeyeFloatingWidgetPlugin>> *)floatingWidgetPlugins
                   defaultSettingUIPluginsInto:(NSMutableArray<id<MTHawkeyeSettingUIPlugin>> *)settingUIPlugins {
    @synchronized(defaultMainPanelPlugins) {
        if (defaultMainPanelPlugins.count == 0 || defaultdefaultFloatingWidgetsPluginsInto.count == 0 || defaultdefaultSettingUIPluginsInto.count == 0)
            [self setupDefaultUIPlugins];

        for (id<MTHawkeyeMainPanelPlugin> plugin in defaultMainPanelPlugins) {
            if (![mainPanelPlugins containsObject:plugin])
                [mainPanelPlugins addObject:plugin];
        }

        for (id<MTHawkeyeSettingUIPlugin> plugin in defaultdefaultSettingUIPluginsInto) {
            if (![settingUIPlugins containsObject:plugin])
                [settingUIPlugins addObject:plugin];
        }

        for (id<MTHawkeyeFloatingWidgetPlugin> plugin in defaultdefaultFloatingWidgetsPluginsInto) {
            if (![floatingWidgetPlugins containsObject:plugin])
                [floatingWidgetPlugins addObject:plugin];
        }
    }
}

+ (void)cleanDefaultUIClientMainPanelPluginsFrom:(NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *)mainPanelPlugins
               defaultFloatingWidgetsPluginsFrom:(NSMutableArray<id<MTHawkeyeFloatingWidgetPlugin>> *)floatingWidgetPlugins
                     defaultSettingUIPluginsFrom:(NSMutableArray<id<MTHawkeyeSettingUIPlugin>> *)settingUIPlugins {
    @synchronized(defaultMainPanelPlugins) {
        for (id<MTHawkeyeMainPanelPlugin> plugin in defaultMainPanelPlugins) {
            if ([mainPanelPlugins containsObject:plugin])
                [mainPanelPlugins removeObject:plugin];
        }

        for (id<MTHawkeyeSettingUIPlugin> plugin in defaultdefaultSettingUIPluginsInto) {
            if ([settingUIPlugins containsObject:plugin])
                [settingUIPlugins removeObject:plugin];
        }

        for (id<MTHawkeyeFloatingWidgetPlugin> plugin in defaultdefaultFloatingWidgetsPluginsInto) {
            if ([floatingWidgetPlugins containsObject:plugin])
                [floatingWidgetPlugins removeObject:plugin];
        }

        [defaultMainPanelPlugins removeAllObjects];
        [defaultdefaultSettingUIPluginsInto removeAllObjects];
        [defaultdefaultFloatingWidgetsPluginsInto removeAllObjects];
    }
}

+ (void)setupDefaultClientPlugins {
    [defaultClientPlugins removeAllObjects];

    // time consuming
    [defaultClientPlugins addObject:[MTFPSHawkeyeAdaptor new]];
    [defaultClientPlugins addObject:[MTHANRHawkeyeAdaptor new]];
    [defaultClientPlugins addObject:[MTHObjcCallTraceHawkeyeAdaptor new]];
    [defaultClientPlugins addObject:[MTHUITimeProfilerHawkeyeAdaptor new]];

    // memory
    [defaultClientPlugins addObject:[MTHLivingObjectsSnifferHawkeyeAdaptor new]];
    [defaultClientPlugins addObject:[MTHAllocationsHawkeyeAdaptor new]];

    // energy
    [defaultClientPlugins addObject:[MTHCPUTraceHawkeyeAdaptor new]];

    // network
    [defaultClientPlugins addObject:[MTHNetworkMonitorHawkeyeAdaptor new]];
    [defaultClientPlugins addObject:[MTHNetworkInspectHawkeyeAdaptor new]];

#ifdef MTH_INCLUDE_GLTRACE
    // graphics
    [defaultClientPlugins addObject:[MTHOpenGLTraceHawkeyeAdaptor new]];
#endif

    // storage
    [defaultClientPlugins addObject:[MTHDirectoryWatcherHawkeyeAdaptor new]];
}

+ (void)setupDefaultUIPlugins {
    [defaultMainPanelPlugins removeAllObjects];
    [defaultdefaultSettingUIPluginsInto removeAllObjects];
    [defaultdefaultFloatingWidgetsPluginsInto removeAllObjects];

    MTHLivingObjectsSnifferHawkeyeUI *livingObjsSnifferUI = [[MTHLivingObjectsSnifferHawkeyeUI alloc] init];
    [defaultMainPanelPlugins addObject:livingObjsSnifferUI];
    [defaultdefaultSettingUIPluginsInto addObject:livingObjsSnifferUI];

    [defaultdefaultFloatingWidgetsPluginsInto addObject:[MTFPSHawkeyeUI new]];

    MTHAllocationsHawkeyeUI *allocationsUI = [MTHAllocationsHawkeyeUI new];
    [defaultMainPanelPlugins addObject:allocationsUI];
    [defaultdefaultSettingUIPluginsInto addObject:allocationsUI];

    MTHANRHawkeyeUI *anrUI = [MTHANRHawkeyeUI new];
    [defaultMainPanelPlugins addObject:anrUI];
    [defaultdefaultSettingUIPluginsInto addObject:anrUI];

    MTHUITimeProfilerHawkeyeUI *timeProfilerUI = [[MTHUITimeProfilerHawkeyeUI alloc] init];
    [defaultMainPanelPlugins addObject:timeProfilerUI];
    [defaultdefaultSettingUIPluginsInto addObject:timeProfilerUI];

    MTHCPUTraceHawkeyeUI *cpuUI = [[MTHCPUTraceHawkeyeUI alloc] init];
    [defaultMainPanelPlugins addObject:cpuUI];
    [defaultdefaultSettingUIPluginsInto addObject:cpuUI];

    MTHNetworkInspectHawkeyeMainPanelUI *netInspectUI = [[MTHNetworkInspectHawkeyeMainPanelUI alloc] init];
    MTHNetworkMonitorHawkeyeMainPanelUI *netMonitorUI = [[MTHNetworkMonitorHawkeyeMainPanelUI alloc] init];
    [defaultMainPanelPlugins addObject:netMonitorUI];
    [defaultMainPanelPlugins addObject:netInspectUI];

    MTHNetworkHawkeyeSettingUI *netSetUI = [[MTHNetworkHawkeyeSettingUI alloc] init];
    [defaultdefaultSettingUIPluginsInto addObject:netSetUI];

#ifdef MTH_INCLUDE_GLTRACE
    MTHOpenGLTraceHawkeyeUI *gltraceUI = [MTHOpenGLTraceHawkeyeUI new];
    [defaultMainPanelPlugins addObject:gltraceUI];
    [defaultdefaultSettingUIPluginsInto addObject:gltraceUI];
    [defaultdefaultFloatingWidgetsPluginsInto addObject:gltraceUI];
#endif

    MTHDirectoryWatcherHawkeyeUI *dirWatcherUI = [[MTHDirectoryWatcherHawkeyeUI alloc] init];
    [defaultMainPanelPlugins addObject:dirWatcherUI];
    [defaultdefaultSettingUIPluginsInto addObject:dirWatcherUI];

    [defaultMainPanelPlugins addObject:[FLEXHawkeyePlugin new]];
}

@end

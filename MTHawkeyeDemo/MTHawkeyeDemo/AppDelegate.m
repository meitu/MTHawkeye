//
//  AppDelegate.m
//  MTHawkeyeDemo
//
//  Created by cqh on 18/05/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import "AppDelegate.h"

//#ifdef DEBUG
#import <MTHawkeye/MTHStackFrameSymbolicsRemote.h>
#import <MTHawkeye/MTRunHawkeyeInOneLine.h>
#import <MTHawkeye/MTHawkeyeStorage.h>
//#endif

#import <MTHawkeye/MTHBackgroundTaskTraceAdaptor.h>
#import <MTHawkeye/MTHBackgroundTaskTraceHawkeyeUI.h>

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(__unused UIApplication *)application didFinishLaunchingWithOptions:(__unused NSDictionary *)launchOptions {
    //#ifdef DEBUG
    [self startHawkeye];
    //#endif
    MTHawkeyeStorage.shared.enableOsLog = YES;

    return YES;
}

- (void)startHawkeye {
#if 0
    [self startDefaultHawkeye];

    // symbolics stack frames in ANR/CPU/Allocations Reports will need a remote symbolics server while the dsym is removed from app.
    // [MTHStackFrameSymbolicsRemote configureSymbolicsServerURL:@"http://xxxx:3002/parse/raw"];
#else
    [self startCustomHawkeye];

    // [MTHStackFrameSymbolicsRemote configureSymbolicsServerURL:@"http://xxxx:3002/parse/raw"];
#endif
}

- (void)startDefaultHawkeye {
    [MTRunHawkeyeInOneLine start];
}

- (void)startCustomHawkeye {
    // Background is not include in `MTHawkeye` by default, you need to add it explicitly.
    MTHBackgroundTaskTraceAdaptor *backgroundTrace = [MTHBackgroundTaskTraceAdaptor new];
    MTHBackgroundTaskTraceHawkeyeUI *backgroundTraceUI = [MTHBackgroundTaskTraceHawkeyeUI new];

    [[MTHawkeyeClient shared]
        setPluginsSetupHandler:^(NSMutableArray<id<MTHawkeyePlugin>> *_Nonnull plugins) {
            [MTHawkeyeDefaultPlugins addDefaultClientPluginsInto:plugins];

            // add your additional plugins here.
            [plugins addObject:backgroundTrace];
        }
        pluginsCleanHandler:^(NSMutableArray<id<MTHawkeyePlugin>> *_Nonnull plugins) {
            // if you don't want to free plugins memory, remove this line.
            [MTHawkeyeDefaultPlugins cleanDefaultClientPluginsFrom:plugins];

            // clean your additional plugins if need.
            [plugins removeObject:backgroundTrace];
        }];

    [[MTHawkeyeClient shared] startServer];

    [[MTHawkeyeUIClient shared]
        setPluginsSetupHandler:^(NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *_Nonnull mainPanelPlugins, NSMutableArray<id<MTHawkeyeFloatingWidgetPlugin>> *_Nonnull floatingWidgetPlugins, NSMutableArray<id<MTHawkeyeSettingUIPlugin>> *_Nonnull defaultSettingUIPluginsInto) {
            [MTHawkeyeDefaultPlugins addDefaultUIClientMainPanelPluginsInto:mainPanelPlugins
                                          defaultFloatingWidgetsPluginsInto:floatingWidgetPlugins
                                                defaultSettingUIPluginsInto:defaultSettingUIPluginsInto];

            // add your additional plugins here.
            [defaultSettingUIPluginsInto addObject:backgroundTraceUI];
        }
        pluginsCleanHandler:^(NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *_Nonnull mainPanelPlugins, NSMutableArray<id<MTHawkeyeFloatingWidgetPlugin>> *_Nonnull floatingWidgetPlugins, NSMutableArray<id<MTHawkeyeSettingUIPlugin>> *_Nonnull defaultSettingUIPluginsInto) {
            // if you don't want to free plugins memory, remove this line.
            [MTHawkeyeDefaultPlugins cleanDefaultUIClientMainPanelPluginsFrom:mainPanelPlugins
                                            defaultFloatingWidgetsPluginsFrom:floatingWidgetPlugins
                                                  defaultSettingUIPluginsFrom:defaultSettingUIPluginsInto];

            // clean your additional plugins if need.
            [defaultSettingUIPluginsInto addObject:backgroundTraceUI];
        }];

    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [[MTHawkeyeUIClient shared] startServer];
    });
}

@end

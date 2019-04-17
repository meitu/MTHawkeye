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
#import "MTHawkeyePlugin.h"
#import "MTHawkeyeUserDefaults.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^MTHawkeyeClientPluginsSetupHandler)(NSMutableArray<id<MTHawkeyePlugin>> *pluginsToAdd);
typedef void (^MTHawkeyeClientPluginsCleanHandler)(NSMutableArray<id<MTHawkeyePlugin>> *pluginsAdded);

@interface MTHawkeyeClient : NSObject

+ (instancetype)shared;

/**
 plugins setup and cleaner

 @param pluginsSetupHandler pluginsSetupHandler will be called while `startServer` invoked.
                            the initial plugin array is empty,
                            after the block, the added plugins will be used to setup client,
                            you can add your own plugins into the array here.

 @param pluginsCleanHandler pluginsCleanHandler will be called while `stopServer` invoked.
                            the plugin array item will be remove internal after stop,
                            you can do cleanup if you've retain the plugins external.
 */
- (void)setPluginsSetupHandler:(MTHawkeyeClientPluginsSetupHandler)pluginsSetupHandler
           pluginsCleanHandler:(MTHawkeyeClientPluginsCleanHandler)pluginsCleanHandler;


/**
 start hawkeye client server, and trigger `hawkeyeClientDidStart` in all plugins.
 */
- (void)startServer;

- (void)stopServer;

/**
 manual call `addPlugin` after startServer will not invoke `hawkeyeClientDidStart`
 */
- (void)addPlugin:(id<MTHawkeyePlugin>)plugin;
- (void)removePlugin:(id<MTHawkeyePlugin>)plugin;
- (nullable id<MTHawkeyePlugin>)pluginFromID:(NSString *)pluginID;

@end

NS_ASSUME_NONNULL_END

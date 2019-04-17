//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/3
// Created by: EuanC
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 The protocol of a Hawkeye client plugin.

 Once you have a new or exist module and wanna add it as Hawkeye client plugin,
 you should implement a adaptor that following MTHawkeyePlugin.

 you can see class `MTHNetworkMonitorHawkeyeAdaptor` as an example.
 */
@protocol MTHawkeyePlugin <NSObject>

@required

/**
 Plugin Identity, should be different with other plugins.
 */
+ (NSString *)pluginID;


/**
 will triggered when Hawkeye client did start.
 */
- (void)hawkeyeClientDidStart;

/**
 will triggered when Hawkeye client did stop.
 */
- (void)hawkeyeClientDidStop;

@optional

/**
 will triggered when Hawkeye client status flush timer fired.
 */
- (void)receivedFlushStatusCommand;

@end

NS_ASSUME_NONNULL_END

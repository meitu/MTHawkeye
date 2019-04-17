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
#import "MTHawkeyeDefaultPlugins.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Run Hawkeye shortly and simply.
 If you need custom plugins, see how `start` work, make your own start.
 */
@interface MTRunHawkeyeInOneLine : NSObject

/**
 If you wanna start with custom plugins, implement your own start method.
 */
+ (void)start;
+ (void)stop;

@end

NS_ASSUME_NONNULL_END

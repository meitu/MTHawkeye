//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 28/08/2017
// Created by: EuanC
//


#import <Foundation/Foundation.h>

@interface MTHNetworkObserver : NSObject

/// Swizzling occurs when the observer is enabled for the first time.
/// NOTE: this setting persists between launches of the app.
+ (void)setEnabled:(BOOL)enabeld;
+ (BOOL)isEnabled;

@end

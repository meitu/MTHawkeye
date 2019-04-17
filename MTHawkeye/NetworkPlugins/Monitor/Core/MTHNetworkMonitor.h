//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 17/07/2017
// Created by: EuanC
//


#import <Foundation/Foundation.h>

@interface MTHNetworkMonitor : NSObject

+ (instancetype)shared;

- (void)start;
- (void)stop;
- (BOOL)isRunning;

@end

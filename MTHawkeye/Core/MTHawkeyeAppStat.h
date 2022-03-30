//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/10
// Created by: EuanC
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTHawkeyeAppStat : NSObject

@property (nonatomic, readonly, class) int64_t memory;

@property (nonatomic, readonly, class) CGFloat availableSizeOfMemory;

@property (nonatomic, readonly, class) double cpuUsedByAllThreads;

@end

NS_ASSUME_NONNULL_END

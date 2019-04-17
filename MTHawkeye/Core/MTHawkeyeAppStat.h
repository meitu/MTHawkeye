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

/// Used memory by app in byte. ( task_basic_info.resident_size )
@property (nonatomic, readonly, class) int64_t memoryAppUsed;

/* The real physical memory used by app.
 - https://stackoverflow.com/questions/9660763/whats-the-right-statistic-for-ios-memory-footprint-live-bytes-real-memory-ot
 - https://developer.apple.com/library/archive/technotes/tn2434/_index.html
 */
@property (nonatomic, readonly, class) int64_t memoryFootprint;

@property (nonatomic, readonly, class) double cpuUsedByAllThreads;

@end

NS_ASSUME_NONNULL_END

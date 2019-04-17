//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 29/06/2017
// Created by: EuanC
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UIDevice (MTHLivingObjectSniffer)

/// Used memory by app in byte.
@property (nonatomic, readonly) int64_t memoryAppUsed;

/* The real physical memory used by app.
 - https://stackoverflow.com/questions/9660763/whats-the-right-statistic-for-ios-memory-footprint-live-bytes-real-memory-ot
 - https://developer.apple.com/library/archive/technotes/tn2434/_index.html
 */
@property (nonatomic, readonly) int64_t memoryFootprint;

/// Total physical memory in byte. (-1 when error occurs)
@property (nonatomic, readonly) int64_t memoryTotal;

/// Used (active + inactive + wired) memory in byte. (-1 when error occurs)
@property (nonatomic, readonly) int64_t memoryUsed;

/// Free memory in byte. (-1 when error occurs)
@property (nonatomic, readonly) int64_t memoryFree;

/// Acvite memory in byte. (-1 when error occurs)
@property (nonatomic, readonly) int64_t memoryActive;

/// Inactive memory in byte. (-1 when error occurs)
@property (nonatomic, readonly) int64_t memoryInactive;

/// Wired memory in byte. (-1 when error occurs)
@property (nonatomic, readonly) int64_t memoryWired;

/// Purgable memory in byte. (-1 when error occurs)
@property (nonatomic, readonly) int64_t memoryPurgable;

@end

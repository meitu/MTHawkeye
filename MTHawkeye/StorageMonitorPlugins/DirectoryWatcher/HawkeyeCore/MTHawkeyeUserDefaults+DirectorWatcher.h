//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/21
// Created by: EuanC
//


#import "MTHawkeyeUserDefaults.h"

typedef NS_OPTIONS(NSUInteger, MTHDirectoryWatcherDetect) {
    kMTHDirectoryWatcherDetectTimingEnterForeground = 1 << 0,
    kMTHDirectoryWatcherDetectTimingEnterBackground = 1 << 1,
};

NS_ASSUME_NONNULL_BEGIN

@interface MTHawkeyeUserDefaults (DirectorWatcher)

@property (nonatomic, assign) BOOL directoryWatcherOn;
@property (nonatomic, assign) NSTimeInterval directoryWatcherStartDelay;

@property (nonatomic, assign) MTHDirectoryWatcherDetect directoryWatcherDetectOptions;
@property (nonatomic, assign) NSUInteger directoryWatcherStopAfterTimes;
@property (nonatomic, assign) NSTimeInterval directoryWatcherReportMinInterval;

@property (atomic, strong) NSArray<NSString *> *directoryWatcherFoldersPath; // NSHomeDirectory() relative path
@property (atomic, strong) NSDictionary<NSString *, NSNumber *> *directoryWatcherFoldersLimitInMB;

@end

NS_ASSUME_NONNULL_END

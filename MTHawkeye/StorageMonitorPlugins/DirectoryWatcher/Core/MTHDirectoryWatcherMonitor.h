//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/11/7
// Created by: Huni
//


#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


typedef void (^__nullable MTHDirectoryWatcherChangeCallback)(NSString *path, NSUInteger folderSize);
typedef void (^__nullable MTHDirectoryWatcherTriggerLimitFiredCallback)(NSString *path);

@interface MTHDirectoryWatcherMonitor : NSObject
/**
 *  Watching paths
 */
@property (nonatomic, strong, readonly) NSArray<NSString *> *watchPaths;

/**
 *  Watching path detect interval
 */
@property (nonatomic, assign) NSTimeInterval detectInterval;

/**
 *  Each watcher change report count archive limit will call this block
 *  You should use removePath: to stop watcher if need
 */
@property (nonatomic, copy) MTHDirectoryWatcherTriggerLimitFiredCallback watcherTriggerLimitFiredCallback;

/**
 *  Each watcher change report event will call this block
 */
@property (nonatomic, copy) MTHDirectoryWatcherChangeCallback watcherChangeCallback;

/**
 *  Monitor watching state
 */
@property (nonatomic, assign, readonly) BOOL isWatching;

+ (instancetype)shared;

/**
 *  Start monitoring
 */
- (void)startWatching;

/**
 *  Stop monitoring
 */
- (void)stopWatching;

/**
 *  Add a monitoring file path
 *
 *  @param path             Will watch the path after startWatching call
 *  @param triggerLimit     Will call watcherTriggerLimitFiredCallback block after triggerLimit archive, 0 never call
 */
- (void)addMonitorPath:(NSString *)path triggerLimit:(NSUInteger)triggerLimit;

/**
 *  Remove a monitoring file path
 *
 *  @param path     Stop watch the path immediately
 */
- (void)removePath:(NSString *)path;

@end

NS_ASSUME_NONNULL_END

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


#import "MTHDirectoryWatcherHawkeyeAdaptor.h"
#import "MTHDirectoryWatcherMonitor.h"
#import "MTHawkeyeUserDefaults+DirectorWatcher.h"

@interface MTHDirectoryWatcherHawkeyeAdaptor ()
@property (nonatomic, strong) NSMutableDictionary *noticeObservers;
@property (nonatomic, strong) NSArray<NSString *> *watcherSettingKey;
@end

@implementation MTHDirectoryWatcherHawkeyeAdaptor
- (NSMutableDictionary *)noticeObservers {
    if (!_noticeObservers) {
        _noticeObservers = [NSMutableDictionary dictionary];
    }
    return _noticeObservers;
}

- (NSArray<NSString *> *)watcherSettingKey {
    if (!_watcherSettingKey) {
        _watcherSettingKey = @[ NSStringFromSelector(@selector(directoryWatcherFoldersPath)) ];
    }
    return _watcherSettingKey;
}

// MARK: - MTHawkeyePlugin
+ (NSString *)pluginID {
    return @"directory-watcher";
}

- (void)hawkeyeClientDidStart {
    if (![MTHawkeyeUserDefaults shared].directoryWatcherOn) {
        if ([MTHDirectoryWatcherMonitor shared].isWatching)
            [[MTHDirectoryWatcherMonitor shared] stopWatching];
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        [self observeWatcherSettingChanges];
        [self configWatcherMonitorDetectOptions];
        [self registerWatcherMonitorTriggerEvent];

        int64_t startDelay = (int64_t)([MTHawkeyeUserDefaults shared].directoryWatcherStartDelay * NSEC_PER_SEC);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, startDelay), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self startWatchingInterestPaths];
        });
    });
}

- (void)hawkeyeClientDidStop {
    [[MTHDirectoryWatcherMonitor shared] stopWatching];
    for (NSString *monitorKey in self.watcherSettingKey) {
        [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:monitorKey];
    }

    for (id observer in self.noticeObservers) {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    }
}

#pragma mark -
- (void)observeWatcherSettingChanges {
    for (NSString *monitorKey in self.watcherSettingKey) {
        __weak typeof(self) weakSelf = self;
        [[MTHawkeyeUserDefaults shared] mth_addObserver:self
                                                 forKey:monitorKey
                                            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                                                [weakSelf startWatchingInterestPaths];
                                            }];
    }
}

- (void)configWatcherMonitorDetectOptions {
    if ([MTHawkeyeUserDefaults shared].directoryWatcherDetectOptions & kMTHDirectoryWatcherDetectTimingEnterForeground) {
        __weak typeof(self) weakSelf = self;
        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification
                                                                        object:nil
                                                                         queue:[NSOperationQueue mainQueue]
                                                                    usingBlock:^(NSNotification *_Nonnull note) {
                                                                        int64_t startDelay = (int64_t)([MTHawkeyeUserDefaults shared].directoryWatcherStartDelay * NSEC_PER_SEC);
                                                                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, startDelay), dispatch_get_main_queue(), ^{
                                                                            [weakSelf startWatchingInterestPaths];
                                                                        });
                                                                    }];
        [self.noticeObservers setObject:observer forKey:UIApplicationWillEnterForegroundNotification];
    }

    if ([MTHawkeyeUserDefaults shared].directoryWatcherDetectOptions & kMTHDirectoryWatcherDetectTimingEnterBackground) {
        __weak typeof(self) weakSelf = self;
        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                                        object:nil
                                                                         queue:[NSOperationQueue mainQueue]
                                                                    usingBlock:^(NSNotification *_Nonnull note) {
                                                                        int64_t startDelay = (int64_t)([MTHawkeyeUserDefaults shared].directoryWatcherStartDelay * NSEC_PER_SEC);
                                                                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, startDelay), dispatch_get_main_queue(), ^{
                                                                            [weakSelf startWatchingInterestPaths];
                                                                        });
                                                                    }];
        [self.noticeObservers setObject:observer forKey:UIApplicationDidEnterBackgroundNotification];
    }

    [MTHDirectoryWatcherMonitor shared].detectInterval = [MTHawkeyeUserDefaults shared].directoryWatcherReportMinInterval;
}

- (void)registerWatcherMonitorTriggerEvent {
    [MTHDirectoryWatcherMonitor shared].watcherChangeCallback = ^(NSString *path, NSUInteger folderSize) {
        NSArray *relativePath = [path componentsSeparatedByString:[NSString stringWithFormat:@"%@/", NSHomeDirectory()]];
        NSNumber *limit = [[MTHawkeyeUserDefaults shared].directoryWatcherFoldersLimitInMB objectForKey:[relativePath lastObject] ?: @""];
        if (folderSize > (limit.floatValue * 1024 * 1024)) {
            [[MTHDirectoryWatcherMonitor shared] removePath:path]; // stop watch this path
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kMTHDirectoryWatcherWarningNotification
                                                                    object:nil
                                                                  userInfo:@{
                                                                      @"folderPath" : [relativePath lastObject] ?: @"",
                                                                      @"sizeInMB" : @(folderSize / 1024.0 / 1024.0)
                                                                  }];
            });
        }
    };

    [MTHDirectoryWatcherMonitor shared].watcherTriggerLimitFiredCallback = ^(NSString *path) {
        [[MTHDirectoryWatcherMonitor shared] removePath:path]; // stop watch this path
        NSArray *remainWatchingPath = [MTHDirectoryWatcherMonitor shared].watchPaths;
        NSArray *relativePath = [path componentsSeparatedByString:[NSString stringWithFormat:@"%@/", NSHomeDirectory()]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kMTHDirectoryWatcherTriggerLimitNotification
                                                                object:nil
                                                              userInfo:@{
                                                                  @"folderPath" : [relativePath lastObject] ?: @"",
                                                                  @"remainWathingPath" : remainWatchingPath
                                                              }];
        });
    };
}

- (void)startWatchingInterestPaths {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSArray<NSString *> *watchingPath = [MTHDirectoryWatcherMonitor shared].watchPaths;
        NSMutableArray<NSString *> *needWatchPath = [NSMutableArray array];
        for (NSString *folderPath in [MTHawkeyeUserDefaults shared].directoryWatcherFoldersPath) {
            [needWatchPath addObject:[NSHomeDirectory() stringByAppendingPathComponent:folderPath]];
        }

        NSArray<NSString *> *uselessPath = [watchingPath filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT (SELF in %@)", needWatchPath]];
        for (NSString *path in uselessPath) {
            [[MTHDirectoryWatcherMonitor shared] removePath:path];
        }

        // if the path have watch done and remove, will start once again or continue
        NSArray<NSString *> *differentPath = [needWatchPath filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT (SELF in %@)", watchingPath]];
        NSUInteger stopAfterCount = [MTHawkeyeUserDefaults shared].directoryWatcherStopAfterTimes;
        if ((differentPath.count != needWatchPath.count) || (differentPath.count == needWatchPath.count && [MTHDirectoryWatcherMonitor shared].isWatching)) {
            stopAfterCount = 1;
        }
        for (NSString *path in differentPath) {
            [[MTHDirectoryWatcherMonitor shared] addMonitorPath:path triggerLimit:stopAfterCount];
        }

        [[MTHDirectoryWatcherMonitor shared] startWatching];
    });
}

@end

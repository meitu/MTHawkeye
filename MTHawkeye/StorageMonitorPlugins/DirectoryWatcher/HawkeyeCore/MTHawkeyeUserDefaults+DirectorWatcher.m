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


#import "MTHawkeyeUserDefaults+DirectorWatcher.h"

@implementation MTHawkeyeUserDefaults (DirectorWatcher)

- (void)setDirectoryWatcherOn:(BOOL)directoryWatcherOn {
    [self setObject:@(directoryWatcherOn) forKey:NSStringFromSelector(@selector(directoryWatcherOn))];
}

- (BOOL)directoryWatcherOn {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(directoryWatcherOn))];
    return value ? value.boolValue : YES;
}

- (void)setDirectoryWatcherFoldersPath:(NSArray<NSString *> *)foldersPath {
    [self setObject:foldersPath forKey:NSStringFromSelector(@selector(directoryWatcherFoldersPath))];
}

- (NSArray<NSString *> *)directoryWatcherFoldersPath {
    NSArray<NSString *> *paths = [self objectForKey:NSStringFromSelector(@selector(directoryWatcherFoldersPath))];
    NSArray<NSString *> *foldersPath = paths.count > 0 ? paths : [NSArray arrayWithObject:@"Documents"];
    return foldersPath;
}

- (void)setDirectoryWatcherFoldersLimitInMB:(NSDictionary<NSString *, NSNumber *> *)foldersLimitInMB {
    [self setObject:foldersLimitInMB forKey:NSStringFromSelector(@selector(directoryWatcherFoldersLimitInMB))];
}

- (NSDictionary<NSString *, NSNumber *> *)directoryWatcherFoldersLimitInMB {
    NSDictionary *originDic = [self objectForKey:NSStringFromSelector(@selector(directoryWatcherFoldersLimitInMB))];
    NSMutableDictionary<NSString *, NSNumber *> *dic = [NSMutableDictionary dictionaryWithDictionary:originDic];
    BOOL valueChanged = NO;
    if (!dic) {
        dic = [NSMutableDictionary dictionary];
        valueChanged = YES;
    }

    NSArray<NSString *> *folderPaths = self.directoryWatcherFoldersPath;
    NSArray<NSString *> *paths = [folderPaths filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", [dic allKeys]]];
    NSArray<NSString *> *uselessPaths = [[dic allKeys] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", folderPaths]];
    for (NSString *path in uselessPaths) {
        [dic removeObjectForKey:path];
    }
    for (NSString *path in paths) {
        [dic setObject:@(200) forKey:path];
        valueChanged = YES;
    }

    if (valueChanged) {
        originDic = dic;
    }
    return originDic;
}

- (void)setDirectoryWatcherDetectOptions:(MTHDirectoryWatcherDetect)detectOptions {
    [self setObject:@(detectOptions) forKey:NSStringFromSelector(@selector(directoryWatcherDetectOptions))];
}

- (MTHDirectoryWatcherDetect)directoryWatcherDetectOptions {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(directoryWatcherDetectOptions))];
    return value.unsignedIntegerValue;
}

- (void)setDirectoryWatcherStopAfterTimes:(NSUInteger)stopWatcherAfterTimes {
    [self setObject:@(stopWatcherAfterTimes) forKey:NSStringFromSelector(@selector(directoryWatcherStopAfterTimes))];
}

- (NSUInteger)directoryWatcherStopAfterTimes {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(directoryWatcherStopAfterTimes))];
    return value ? value.unsignedIntegerValue : 3;
}

- (void)setDirectoryWatcherReportMinInterval:(NSTimeInterval)reportMinInterval {
    [self setObject:@(reportMinInterval) forKey:NSStringFromSelector(@selector(directoryWatcherReportMinInterval))];
}

- (NSTimeInterval)directoryWatcherReportMinInterval {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(directoryWatcherReportMinInterval))];
    return value ? value.floatValue : 40;
}

- (void)setDirectoryWatcherStartDelay:(NSTimeInterval)startDelay {
    [self setObject:@(startDelay) forKey:NSStringFromSelector(@selector(directoryWatcherStartDelay))];
}

- (NSTimeInterval)directoryWatcherStartDelay {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(directoryWatcherStartDelay))];
    return value ? value.doubleValue : 5.f;
}

@end

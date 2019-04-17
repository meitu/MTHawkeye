//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/11/6
// Created by: Huni
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MTHDirectoryWatcher;

@protocol MTHDirectoryWatcherDelegate <NSObject>
@required
- (void)directoryDidChange:(MTHDirectoryWatcher *)directoryWatcher;
@end

@interface MTHDirectoryWatcher : NSObject

@property (nonatomic, assign, readonly) CGFloat folderSize;
@property (nonatomic, copy, readonly) NSString *watchPath;

@property (nonatomic, assign) NSUInteger reportCount;
@property (nonatomic, assign) NSTimeInterval changeReportInterval;

+ (MTHDirectoryWatcher *)directoryWatcherWithPath:(NSString *)watchPath
                             changeReportInterval:(NSTimeInterval)changeReportInterval
                                         delegate:(id<MTHDirectoryWatcherDelegate>)watchDelegate;

+ (unsigned long long)fileSizeAtPath:(NSString *)path;

- (void)invalidate;

@end

NS_ASSUME_NONNULL_END

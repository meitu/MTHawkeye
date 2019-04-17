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


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN


@class MTHNetworkTransaction;

@protocol MTHNetworkWaterfallDataSource

- (NSTimeInterval)timelineStartAt;
- (NSTimeInterval)timelineDuration;

- (nullable NSArray<MTHNetworkTransaction *> *)networkTransactions;
- (NSInteger)requestIndexFocusOnCurrently;

- (nullable NSArray<NSNumber *> *)currentOnViewIndexArray;
- (nullable MTHNetworkTransaction *)transactionFromRequestIndex:(NSInteger)requestIndex;

@end

@interface MTHNetworkWaterfallViewController : UIViewController

@property (nonatomic, strong) id<MTHNetworkWaterfallDataSource> dataSource;

- (instancetype)initWithViewModel:(id<MTHNetworkWaterfallDataSource>)dataSource;

- (void)reloadData;

- (void)updateContentInset;

@end


NS_ASSUME_NONNULL_END

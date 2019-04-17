//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2017/9/5
// Created by: 潘名扬
//


#import <Foundation/Foundation.h>
#import "MTHNetworkWaterfallViewController.h"

NS_ASSUME_NONNULL_BEGIN

@class MTHNetworkTransaction;

@interface MTHNetworkTransactionAdviceDetailViewModel : NSObject <MTHNetworkWaterfallDataSource>

// 当前聚焦的网络请求记录下标
@property (nonatomic, assign) NSInteger requestIndexFocusOnCurrently;

// 当前显示的关联网络请求记录下标数组，包含聚焦的请求
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *currentOnViewIndexArray;

@property (nonatomic, assign) NSTimeInterval timelineStartAt;  // 当前关注的 timeline 的起始时间
@property (nonatomic, assign) NSTimeInterval timelineDuration; // 当前关注的 timeline 总时长

- (instancetype)initWithRequestIndex:(NSInteger)index relatedRequestIndexes:(NSIndexSet *)indexes;

- (MTHNetworkTransaction *)transactionFromRequestIndex:(NSInteger)requestIndex;

@end

NS_ASSUME_NONNULL_END

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


#import <Foundation/Foundation.h>
#import "MTHNetworkTransaction.h"
#import "MTHNetworkWaterfallViewController.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MTHNetworkRecordsDisplayMode) {
    MTHNetworkRecordsDisplayModeFull = 0,           // 展示完整的网络请求记录列表
    MTHNetworkRecordsDisplayModeParallel,           // 展示选中时刻同时执行中的网络请求记录列表
    MTHNetworkRecordsDisplayModeRepeatTransactions, // 分组展示重复的网络记录请求
    MTHNetworkRecordsDisplayModeDomainFilter,       // 展示根据域名过滤的网络请求记录列表
    MTHNetworkRecordsDisplayModeRspCodeFilter,      // 展示根据 http code 过滤的网络请求记录列表
    MTHNetworkRecordsDisplayModeTimeoutFilter,      // 展示网络超时可能不合理的网络请求记录列表
};

@class MTHNetworkTaskAdvice;
@class MTHNetworkTransactionsURLFilter;
@class MTHNetworkTaskInspectionWithResult;

@interface MTHNetworkMonitorViewModel : NSObject <MTHNetworkWaterfallDataSource>

@property (nonatomic, assign) MTHNetworkRecordsDisplayMode displayMode;

@property (nonatomic, assign) BOOL isPresentingSearch;

// 当前显示的网络请求记录列表
@property (nonatomic, readonly) NSArray<MTHNetworkTransaction *> *networkTransactions;

// 过滤的网络请求记录列表
@property (nonatomic, readonly) NSArray<MTHNetworkTransaction *> *filteredNetworkTransactions;

//
- (nullable NSArray<MTHNetworkTaskAdvice *> *)advicesForTransaction:(MTHNetworkTransaction *)transaction;

// 当当前聚焦的请求 r1 未完成时，之后展示的请求数不依赖于 r1 的结束时间，此属性用于限制展示的数量
@property (nonatomic, assign) NSInteger maxFollowingWhenFocusNotResponse;

// 当前聚焦的网络请求记录下标, 调用 focusOnTransactionWithIndex: 时会更新
@property (nonatomic, assign, readonly) NSInteger requestIndexFocusOnCurrently;

// 当前显示的关联网络请求记录下标数组，包含聚焦的请求，调用 focusOnTransactionWithIndex: 时会更新
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *currentOnViewIndexArray;

@property (nonatomic, assign) NSTimeInterval timelineStartAt;  // 当前关注的 timeline 的起始时间
@property (nonatomic, assign) NSTimeInterval timelineDuration; // 当前关注的 timeline 总时常

// 搜索过滤相关
@property (nonatomic, copy) NSString *currentSearchText;
@property (nonatomic, strong) MTHNetworkTransactionsURLFilter *filter;
@property (nonatomic, copy) NSSet<NSString *> *warningAdviceTypeIDs; /**< Cell 上不显示特定 inspection 的警告 */

- (void)focusOnTransactionWithRequestIndex:(NSInteger)requestIndex;

- (NSInteger)viewIndexFromRequestIndex:(NSInteger)requestIndex;
- (MTHNetworkTransaction *)transactionFromRequestIndex:(NSInteger)requestIndex;


- (void)updateSearchResultsWithText:(NSString *)searchText completion:(void (^)(void))completion;

// transactions update
- (void)loadTransactionsWithInspectComoletion:(void (^)(void))inspectCompetion;
- (void)incomeNewTransactions:(NSArray<MTHNetworkTransaction *> *)transactions inspectCompletion:(void (^)(void))inspectCompetion;

@end

NS_ASSUME_NONNULL_END

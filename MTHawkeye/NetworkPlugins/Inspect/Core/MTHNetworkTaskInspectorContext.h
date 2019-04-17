//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 25/08/2017
// Created by: EuanC
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@class MTHNetworkTransaction;

// MARK: - MTHTopLevelDomain
/**
 顶级域名类

 利用 NSString 去重
 */
@interface MTHTopLevelDomain : NSObject

@property (nonatomic, copy) NSString *domainString;
@property (nonatomic, strong) NSMutableSet<NSString *> *secondLevelDomains;

- (instancetype)initWithString:(NSString *)domainString;

@end


// MARK: - MTHNetworkTaskInspectorContext
@interface MTHNetworkTaskInspectorContext : NSObject

@property (nonatomic, readonly) NSArray<MTHNetworkTransaction *> *transactions;


/**
 使用网络请求记录列表，初始化 InspectorContext 环境
 */
- (void)updateContextWithTransactions:(NSArray<MTHNetworkTransaction *> *)transactions;


// MARK: - For NSURLSessionTask Manager
/**
 记录创建了同一 Host 的 URLSessionTask 所在的 NSURLSession 个数
 正常应该为 1，不合理使用时会有多个 NSURLSession 创建同一类型的 task
 key: host
 value: NSCountedSet<urlSessionTask.NSURLSession.pointerString(count)>
 */
@property (nonatomic, strong, nullable) NSMutableDictionary *taskSessionsGroupbyHost;

/**
 记录所有网络请求涉及到的一级和二级域名
 */
@property (nonatomic, strong, nullable) NSMutableSet<MTHTopLevelDomain *> *topLevelDomains;

/**
 记录每个独立的 NSURLSession 所创建的 Task 总数
 element: urlSessionTask.NSURLSession.pointerString(count)
 */
@property (nonatomic, copy, nullable) NSCountedSet *countedTaskSessions;


// MARK: - For duplicated transactions
@property (nonatomic, strong, nullable) NSMutableOrderedSet *hashKeySet;
@property (nonatomic, strong, nullable) NSMutableArray *duplicatedGroups;
@property (nonatomic, assign) int64_t duplicatedPayloadCost; // 记录重复的网络请求多消耗的网络流量

- (NSString *)hashKeyForTransaction:(MTHNetworkTransaction *)transaction;

// MARK: - For Parallel transactions
- (NSArray<MTHNetworkTransaction *> *)parallelTransactionsBefore:(MTHNetworkTransaction *)transaction;

@property (nonatomic, strong, nullable) NSMutableArray *containDNSCostRequestIndexesOnStartup;
@property (nonatomic, strong, nullable) NSMutableArray *containTCPConnCostRequestIndexesOnStartup;
@property (nonatomic, assign) NSTimeInterval dnsCostTotalOnStartup;
@property (nonatomic, assign) NSTimeInterval tcpConnCostTotalOnStartup;

- (NSArray<MTHNetworkTransaction *> *)transactionsForRequestIndexes:(NSIndexSet *)indexes;

@end

NS_ASSUME_NONNULL_END

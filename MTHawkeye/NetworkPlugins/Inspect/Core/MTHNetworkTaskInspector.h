//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 24/08/2017
// Created by: EuanC
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MTHNetworkTaskInspection;
@class MTHNetworkTaskInspectorContext;
@class MTHNetworkTaskInspectResults;
@class MTHNetworkTransaction;
@class MTHNetworkRecorder;
@class MTHNetworkTaskAdvice;

@protocol MTHNetworkInspectInfoDelegate <NSObject>

- (void)requestCacheNetworkInspectResult:(NSDictionary *)inspectResultDic withKey:(NSString *)key;
- (NSDictionary *)existNetworkInspectResultsCache;

@end


@interface MTHNetworkTaskInspector : NSObject

/**
 网络任务侦测项列表，需要关闭内置的侦测项时，可遍历找到对应项，将 enabled 置为 NO.
 */
@property (nonatomic, copy, readonly) NSArray<MTHNetworkTaskInspection *> *inspections;

// IMPROVE: context 不应该由外部去更新，由内部处理
@property (nonatomic, strong, readonly) MTHNetworkTaskInspectorContext *context;

@property (nonatomic, strong, readonly) MTHNetworkTaskInspectResults *inspectResults;

@property (nonatomic, weak) id<MTHNetworkInspectInfoDelegate> storageDelegate;

/**
 可设置此域名黑名单，来过滤一些第三方 sdk 的网络请求侦测

 host 匹配规则为后半段部分匹配: [transaction.request.URL.host hasSuffix:host]
 */
@property (nonatomic, copy) NSArray<NSString *> *hostBlackList;

+ (instancetype)shared;

+ (void)setEnabled:(BOOL)enabled;
+ (BOOL)isEnabled;

/**
 上层可调用此方法增加自己的策略，策略的实现可查看 `MTHNetworkTaskInspectionScheduling` 等类；

 需要关闭某一侦测项时，现在暂不提供显示的方法。上层可遍历本类的 `inspections` 属性，找到对应的侦测项
 将 enabled 置为 NO，即可关闭对应的侦测。
 */
- (void)addInspection:(MTHNetworkTaskInspection *)inspection;


/**
 侦测传入的网络请求是否存在问题
 使用已加入的 inspections 作为侦测器
 */
- (void)inspectTransactions:(NSArray<MTHNetworkTransaction *> *)transactions
          completionHandler:(void (^)(NSDictionary<NSString *, NSArray<MTHNetworkTaskAdvice *> *> *))completionHandler;

- (void)releaseNetworkTaskInspectorElement;

@end

NS_ASSUME_NONNULL_END

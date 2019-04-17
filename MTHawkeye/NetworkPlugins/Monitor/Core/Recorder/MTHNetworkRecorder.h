//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 25/07/2017
// Created by: EuanC
//


#import <Foundation/Foundation.h>
#import "MTHNetworkTransaction.h"

NS_ASSUME_NONNULL_BEGIN


@class MTHNetworkTaskAPIUsage;
@class MTHNetworkTaskSessionConfigAPIUsage;
@class MTHNetworkTransaction;
@class MTHNetworkRepeatTransactions;

@protocol MTHNetworkRecorderDelegate;

@interface MTHNetworkRecorder : NSObject

/// In general, it only makes sense to have one recorder for the entire application.
+ (instancetype)defaultRecorder;

- (void)addDelegate:(id<MTHNetworkRecorderDelegate>)delegate;
- (void)removeDelegate:(id<MTHNetworkRecorderDelegate>)delegate;


/// Array of MTHawkeyeNetworkTransaction objects ordered by start time with the newest first.
/// You must read transactions from the storage module and set them to this property, before inspection.
/// Since it is a weak property, You have to hold a strong reference to the array until you don't need it.
//@property (nonatomic, weak) NSArray<MTHNetworkTransaction *> *networkTransactions;

///// 记录 response data 的 MD5 值，用于侦测重复的网络请求
//@property (nonatomic, assign) BOOL shouldCacheResponseDataMD5;

@property (nonatomic, copy) NSArray<NSString *> *hostBlacklist;

/// 记录重复的网络请求时，在此黑名单内的不计入
//@property (nonatomic, copy) NSArray<NSString *> *repeatTransactionsHostBlackList;


// Recording network activity

/// Call when app is about to send HTTP request.
- (void)recordRequestWillBeSentWithRequestID:(NSString *)requestID
                                     request:(NSURLRequest *)request
                            redirectResponse:(nullable NSURLResponse *)redirectResponse;

/// Call to collect API Usage before HTTP request completed for Network Inpect.
- (void)recordRequestTaskAPIUsageWithRequestID:(NSString *)requestID
                                  taskAPIUsage:(MTHNetworkTaskAPIUsage *)taskAPIUsage
                     taskSessionConfigAPIUsage:(MTHNetworkTaskSessionConfigAPIUsage *)taskSessionConfigAPIUsage;

/// Call when HTTP response is available.
- (void)recordResponseReceivedWithRequestID:(NSString *)requestID response:(NSURLResponse *)response;

/// Call when data chunk is received over the network.
- (void)recordDataReceivedWithRequestID:(NSString *)requestID dataLength:(int64_t)dataLength;

/// Call when HTTP request has finished loading.
- (void)recordLoadingFinishedWithRequestID:(NSString *)requestID responseBody:(NSData *)responseBody;

/// Call when HTTP request has failed to load.
- (void)recordLoadingFailedWithRequestID:(NSString *)requestID error:(NSError *)error;

/// 后续统一切换使用 Metrics 来统计，主要调整 redirect request 相关逻辑
- (void)recordMetricsWithRequestID:(NSString *)requestID metrics:(NSURLSessionTaskMetrics *)metrics NS_AVAILABLE_IOS(10_0);

/// Call to set the request mechanism anytime after recordRequestWillBeSent... has been called.
/// This string can be set to anything useful about the API used to make the request.
- (void)recordMechanism:(NSString *)mechanism forRequestID:(NSString *)requestID;

@end


@protocol MTHNetworkRecorderDelegate <NSObject>

@optional

- (void)recorderWantCacheTransactionAsUpdated:(MTHNetworkTransaction *)transaction currentState:(MTHNetworkTransactionState)state;
- (void)recorderWantCacheNewTransaction:(MTHNetworkTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END

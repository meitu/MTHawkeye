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
#import <UIKit/UIKit.h>
#import "MTHNetworkStat.h"
#import "MTHURLSessionTaskMetrics.h"

#ifndef MTHawkeyeNetworkDebugEnabled
#define MTHawkeyeNetworkDebugEnabled 0
#endif

typedef NS_ENUM(NSInteger, MTHNetworkTransactionState) {
    MTHNetworkTransactionStateUnstarted,
    MTHNetworkTransactionStateAwaitingResponse,
    MTHNetworkTransactionStateReceivingData,
    MTHNetworkTransactionStateFinished,
    MTHNetworkTransactionStateFailed
};

typedef NS_ENUM(NSInteger, MTHNetworkHTTPContentType) {
    MTHNetworkHTTPContentTypeJSON = 0,
    MTHNetworkHTTPContentTypeXML,
    MTHNetworkHTTPContentTypeHTML,
    MTHNetworkHTTPContentTypeOther,
    MTHNetworkHTTPContentTypeText,
    MTHNetworkHTTPContentTypeNULL
};

typedef NS_ENUM(NSInteger, MTHNetworkTransactionStatusCode) {
    MTHNetworkTransactionStatusCodeNone = 0,
    MTHNetworkTransactionStatusCode1xx = 1 << 0,
    MTHNetworkTransactionStatusCode2xx = 1 << 1,
    MTHNetworkTransactionStatusCode3xx = 1 << 2,
    MTHNetworkTransactionStatusCode4xx = 1 << 3,
    MTHNetworkTransactionStatusCode5xx = 1 << 4,
    MTHNetworkTransactionStatusCodeNoResponse = 1 << 5,
    MTHNetworkTransactionStatusCodeFailed = (MTHNetworkTransactionStatusCode4xx
                                             | MTHNetworkTransactionStatusCode5xx
                                             | MTHNetworkTransactionStatusCodeNoResponse), /**< failed (4xx || 5xx || not response ...) */
};

/**
 用于记录 URLSessionTask 网络请求时的参数，用于一些网络优化建议
 */
@interface MTHNetworkTaskAPIUsage : NSObject

/// 用于标记当前 SessionTask 所关联的 Session 内存地址。后续用于对比是否使用同一 Session 管理同类 task
@property (nonatomic, copy) NSString *taskSessionIdentify;

/// NSURLSessionTask:priority 任务优先级
@property (nonatomic, assign) CGFloat taskPriority;

@end

/**
 用于记录 URLSessionTask 的 sessionConfiguration 的一些参数，用于一些网络使用建议
 */
@interface MTHNetworkTaskSessionConfigAPIUsage : NSObject

@property (nonatomic, assign) BOOL sessionConfigShouldUsePipeliningEnabled;
@property (nonatomic, assign) NSTimeInterval sessionConfigTimeoutIntervalForRequest;
@property (nonatomic, assign) NSTimeInterval sessionConfigTimeoutIntervalForResource;
@property (nonatomic, assign) NSInteger sessionConfigHTTPMaximumConnectionsPerHost;

@end

// MAKR: -

@interface MTHNetworkTransaction : NSObject

@property (nonatomic, copy) NSString *requestID;
@property (nonatomic, assign) NSInteger requestIndex; // 请求序列号，从1开始

@property (nonatomic, copy) NSURLRequest *request;
@property (nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, assign) NSInteger requestLength;
@property (nonatomic, assign) NSInteger responseLength;
@property (nonatomic, copy) NSString *requestMechanism;
@property (atomic, assign) MTHNetworkTransactionState transactionState;
@property (nonatomic, strong) NSError *error;

@property (nonatomic, copy) NSDate *startTime;
@property (nonatomic, assign) NSTimeInterval latency;
@property (nonatomic, assign) NSTimeInterval duration;

//
// iOS10 开始，使用 NSURLSessionTaskMetrics 来管理网络请求记录, 设置 taskMetrics 时开启
//
@property (nonatomic, assign, readonly) BOOL useURLSessionTaskMetrics;
@property (nonatomic, strong) MTHURLSessionTaskMetrics *taskMetrics API_AVAILABLE(ios(10.0));

@property (nonatomic, assign) MTHawkeyeNetworkConnectionQuality netQualityAtStart; // 任务创建时的网络状态
@property (nonatomic, assign) MTHawkeyeNetworkConnectionQuality netQualityAtEnd;   // 任务结束时的网络状态

@property (atomic, assign) int64_t receivedDataLength;

/// Only applicable for image downloads. A small thumbnail to preview the full response.
@property (nonatomic, strong) UIImage *responseThumbnail;

/// 目前此属性仅在侦测网络质量时过滤使用，实现时直接去判断 [NSURLCache sharedURLCache]，逻辑上不严谨
@property (nonatomic, assign) BOOL isResponseFromCache;

/// Populated lazily. Handles both normal HTTPBody data and HTTPBodyStreams.
@property (nonatomic, copy, readonly) NSData *cachedRequestBody;

@property (nonatomic, copy) NSData *responseBody;

@property (nonatomic, assign) MTHNetworkHTTPContentType responseContentType;

@property (nonatomic, copy) NSString *responseDataMD5;

@property (nonatomic, assign) BOOL repeated; // 是否为重复的网络请求

/// 用于区分是 NSURLConnection 还是 NSURLSession
@property (nonatomic, assign) BOOL isUsingURLSession;

/// for inspector: current task.
@property (nonatomic, strong) MTHNetworkTaskAPIUsage *sessionTaskAPIUsage;

/// for inspector: NSURLSessionConfiguration for current task.
@property (nonatomic, strong) MTHNetworkTaskSessionConfigAPIUsage *sessionConfigAPIUsage;

/**
 用 dictionary 创建出一个 transaction。

 @param dictionary 包含所有关键属性的 dictionary。
 @return 创建出来的 dictionary，如果创建失败，则返回 nil。
 */
+ (instancetype)transactionFromPropertyDictionary:(NSDictionary *)dictionary;

+ (NSString *)readableStringFromTransactionState:(MTHNetworkTransactionState)state;


/**
 生成包含 transaction 中关键 property 的 dictionary。

 @discussion 可以用生成的 dictionary 创建出这个 transaction。
 */
- (NSDictionary *)dictionaryFromAllProperty;

@end

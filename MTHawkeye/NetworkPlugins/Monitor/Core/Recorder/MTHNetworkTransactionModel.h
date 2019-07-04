//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2019/7/4
// Created by: David.Dai
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// MARK: -
API_AVAILABLE(ios(10.0))
@interface MTHURLSessionTaskTransactionMetrics : NSObject
@property (copy) NSURLRequest *request;
@property (nullable, copy) NSURLResponse *response;
@property (nullable, copy) NSDate *fetchStartDate;
@property (nullable, copy) NSDate *domainLookupStartDate;
@property (nullable, copy) NSDate *domainLookupEndDate;
@property (nullable, copy) NSDate *connectStartDate;
@property (nullable, copy) NSDate *secureConnectionStartDate;
@property (nullable, copy) NSDate *secureConnectionEndDate;
@property (nullable, copy) NSDate *connectEndDate;
@property (nullable, copy) NSDate *requestStartDate;
@property (nullable, copy) NSDate *requestEndDate;
@property (nullable, copy) NSDate *responseStartDate;
@property (nullable, copy) NSDate *responseEndDate;
@property (nullable, copy) NSString *networkProtocolName;
@property (assign, getter=isProxyConnection) BOOL proxyConnection;
@property (assign, getter=isReusedConnection) BOOL reusedConnection;
@property (assign) NSURLSessionTaskMetricsResourceFetchType resourceFetchType;
@end

API_AVAILABLE(ios(10.0))
@interface MTHURLSessionTaskMetrics : NSObject
@property (copy) NSArray<MTHURLSessionTaskTransactionMetrics *> *transactionMetrics;
@property (copy) NSDateInterval *taskInterval;
@property (assign) NSUInteger redirectCount;
@property (strong) NSURLSessionTaskMetrics *urlSessionTaskMetrics;

+ (MTHURLSessionTaskMetrics *)metricsFromSystemMetrics:(NSURLSessionTaskMetrics *)urlSessionTaskMetrics;
@end
NS_ASSUME_NONNULL_END

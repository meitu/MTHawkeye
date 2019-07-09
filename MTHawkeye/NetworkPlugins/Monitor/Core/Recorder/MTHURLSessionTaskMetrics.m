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


#import "MTHURLSessionTaskMetrics.h"

@implementation MTHURLSessionTaskTransactionMetrics

@end

@implementation MTHURLSessionTaskMetrics

+ (MTHURLSessionTaskMetrics *)metricsFromSystemMetrics:(NSURLSessionTaskMetrics *)urlSessionTaskMetrics {
    MTHURLSessionTaskMetrics *metrics = [[MTHURLSessionTaskMetrics alloc] init];
    metrics.urlSessionTaskMetrics = urlSessionTaskMetrics;
    metrics.redirectCount = urlSessionTaskMetrics.redirectCount;
    metrics.taskInterval = urlSessionTaskMetrics.taskInterval;

    NSMutableArray *arry = [NSMutableArray arrayWithCapacity:urlSessionTaskMetrics.transactionMetrics.count];
    for (NSURLSessionTaskTransactionMetrics *transcationMetric in urlSessionTaskMetrics.transactionMetrics) {
        MTHURLSessionTaskTransactionMetrics *mthTranscationMetric = [[MTHURLSessionTaskTransactionMetrics alloc] init];
        mthTranscationMetric.response = transcationMetric.response;
        mthTranscationMetric.fetchStartDate = transcationMetric.fetchStartDate;
        mthTranscationMetric.domainLookupStartDate = transcationMetric.domainLookupStartDate;
        mthTranscationMetric.domainLookupEndDate = transcationMetric.domainLookupEndDate;
        mthTranscationMetric.connectStartDate = transcationMetric.connectStartDate;
        mthTranscationMetric.connectEndDate = transcationMetric.connectEndDate;
        mthTranscationMetric.secureConnectionStartDate = transcationMetric.secureConnectionStartDate;
        mthTranscationMetric.secureConnectionEndDate = transcationMetric.secureConnectionEndDate;
        mthTranscationMetric.requestStartDate = transcationMetric.requestStartDate;
        mthTranscationMetric.requestEndDate = transcationMetric.requestEndDate;
        mthTranscationMetric.responseStartDate = transcationMetric.responseStartDate;
        mthTranscationMetric.responseEndDate = transcationMetric.responseEndDate;
        mthTranscationMetric.networkProtocolName = transcationMetric.networkProtocolName;
        mthTranscationMetric.proxyConnection = transcationMetric.isProxyConnection;
        mthTranscationMetric.reusedConnection = transcationMetric.isReusedConnection;
        mthTranscationMetric.resourceFetchType = transcationMetric.resourceFetchType;
        [arry addObject:mthTranscationMetric];
    }
    metrics.transactionMetrics = arry;
    return metrics;
}

@end

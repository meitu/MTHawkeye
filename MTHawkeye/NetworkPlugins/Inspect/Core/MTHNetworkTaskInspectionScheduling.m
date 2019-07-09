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


#import "MTHNetworkTaskInspectionScheduling.h"
#import "MTHNetworkTaskAdvice.h"
#import "MTHNetworkTaskInspection.h"
#import "MTHNetworkTaskInspectorContext.h"
#import "MTHNetworkTransaction.h"
#import "MTHawkeyeUtility.h"


NSInteger gMTHNetworkInspectionStartupIncludingSeconds = 5.0; // seconds

NSString *kMTHNetworkTaskAdviceKeyParallelRequestIndexList = @"MTHNetworkTaskAdviceKeyParallelRequestIDList";

@implementation MTHNetworkTaskInspectionScheduling


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"

NSInteger gMTHNetworkInspectionStartupHeavyTransactionCostLimit = 1.5f;

/**
 侦测启动期间 (目前设定为启动 5s 内) 时间较长的请求
 */
+ (MTHNetworkTaskInspection *)startupHeavyRequestTaskInspection {
    static MTHNetworkTaskInspection *inspection = nil;
    if (inspection != nil) {
        return inspection;
    }

    inspection = [[MTHNetworkTaskInspection alloc] init];
    inspection.group = @"Scheduling";
    inspection.name = @"Heavy Request Task On Startup Inspection";
    inspection.displayName = @"Detecting heavy requests during startup";
    inspection.guide = @"";

    MTHNetworkTaskInspectionParamEntity *startupDurationParam = [[MTHNetworkTaskInspectionParamEntity alloc] init];
    startupDurationParam.displayName = @"Detecting time requests at startup";
    startupDurationParam.valueType = MTHNetworkTaskInspectionParamValueTypeFloat;
    startupDurationParam.valueUnits = @"s";
    startupDurationParam.value = @(gMTHNetworkInspectionStartupIncludingSeconds);

    MTHNetworkTaskInspectionParamEntity *requestDurationLimitParam = [[MTHNetworkTaskInspectionParamEntity alloc] init];
    requestDurationLimitParam.displayName = @"Timeout request";
    requestDurationLimitParam.valueType = MTHNetworkTaskInspectionParamValueTypeFloat;
    requestDurationLimitParam.valueUnits = @"s";
    requestDurationLimitParam.value = @(1.5f);

    inspection.inspectCustomParams = @{
        @"StartupDuration" : startupDurationParam,
        @"RequestDurationLimit" : requestDurationLimitParam,
    };

    inspection.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transactionToInspect, MTHNetworkTaskInspectorContext *context) {

        CGFloat starupDuration = [startupDurationParam.value floatValue];
        CGFloat requestDurationLimit = [requestDurationLimitParam.value floatValue];

        CGFloat starupDiff = [transactionToInspect.startTime timeIntervalSince1970] - [MTHawkeyeUtility appLaunchedTime];
        if (starupDiff > starupDuration) {
            return nil;
        }

        if (transactionToInspect.duration > requestDurationLimit) {
            MTHNetworkTaskAdvice *advice = [[MTHNetworkTaskAdvice alloc] init];
            advice.typeId = @"Heavy Transaction on Startup";
            advice.level = MTHNetworkTaskAdviceLevelMiddle;
            advice.requestIndex = transactionToInspect.requestIndex;
            advice.adviceTitleText = @"Requests timed out during startup";
            advice.adviceDescText = [NSString stringWithFormat:@"This request occurred at %.2fs after startup, which took %.2fs and exceeded the expected value of %.2fs. \n\nMechanism:  %@", starupDiff, transactionToInspect.duration, requestDurationLimit, transactionToInspect.requestMechanism];

            advice.suggestDescText = @"If the packet is large, split it to reduce the size of the packet during startup；\n\n"
                                     @"If there are more concurrent requests during startup, can reduce some unnecessary during startup, post it processing；\n\n"
                                     @"If DNS times out, reducing DNS time with MTFastDNS or other.\n";

            return @[ advice ];
        }
        return nil;
    };
    return inspection;
}

NSInteger gMTHNetworkInspectionStartupDNSCostLimit = 0.2; //

+ (MTHNetworkTaskInspection *)startupDNSCostInspection {
    static MTHNetworkTaskInspection *inspection = nil;
    if (inspection != nil) {
        return inspection;
    }

    inspection = [[MTHNetworkTaskInspection alloc] init];
    inspection.group = @"Scheduling";
    inspection.name = @"DNS Cost Inspection On Startup";
    inspection.displayName = @"Detecting long DNS cost during startup";
    inspection.guide = @"";

    MTHNetworkTaskInspectionParamEntity *startupDurationParam = [[MTHNetworkTaskInspectionParamEntity alloc] init];
    startupDurationParam.displayName = @"Detecting time requests at startup";
    startupDurationParam.valueType = MTHNetworkTaskInspectionParamValueTypeFloat;
    startupDurationParam.valueUnits = @"s";
    startupDurationParam.value = @(gMTHNetworkInspectionStartupIncludingSeconds);

    MTHNetworkTaskInspectionParamEntity *dnsCostLimitParam = [[MTHNetworkTaskInspectionParamEntity alloc] init];
    dnsCostLimitParam.displayName = @"Detecting DNS timeout during startup";
    dnsCostLimitParam.valueType = MTHNetworkTaskInspectionParamValueTypeFloat;
    dnsCostLimitParam.valueUnits = @"s";
    dnsCostLimitParam.value = @(gMTHNetworkInspectionStartupDNSCostLimit);

    inspection.inspectCustomParams = @{
        @"StartupDuration" : startupDurationParam,
        @"DNSCostLimit" : dnsCostLimitParam,
    };

    inspection.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transaction, MTHNetworkTaskInspectorContext *context) {

        CGFloat startupDuration = [startupDurationParam.value floatValue];
        CGFloat dnsCostLimit = [dnsCostLimitParam.value floatValue];

        if (([transaction.startTime timeIntervalSince1970] - [MTHawkeyeUtility appLaunchedTime]) > startupDuration) {
            return nil;
        }

        if (context.containDNSCostRequestIndexesOnStartup == nil) {
            context.containDNSCostRequestIndexesOnStartup = [NSMutableArray array];
        }

        NSTimeInterval dnsDurationCost = 0.f;
        for (MTHURLSessionTaskTransactionMetrics *metrics in transaction.taskMetrics.transactionMetrics) {
            NSTimeInterval itemDnsDuration = [metrics.domainLookupEndDate timeIntervalSinceDate:metrics.domainLookupStartDate];
            if (itemDnsDuration > 0.001f) {
                context.dnsCostTotalOnStartup += itemDnsDuration;
                dnsDurationCost += itemDnsDuration;
            }
        }
        if (dnsDurationCost > 0.001f) {
            // insert by order
            if (context.containDNSCostRequestIndexesOnStartup.count == 0) {
                [context.containDNSCostRequestIndexesOnStartup addObject:@[ @(transaction.requestIndex), @(dnsDurationCost) ]];
            } else {
                [context.containDNSCostRequestIndexesOnStartup enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                    NSInteger itemRequestIndex = [obj[0] integerValue];
                    if (itemRequestIndex < transaction.requestIndex) {
                        [context.containDNSCostRequestIndexesOnStartup insertObject:@[ @(transaction.requestIndex), @(dnsDurationCost) ] atIndex:idx];
                        *stop = YES;
                    }
                }];
            }
        }

        if (context.dnsCostTotalOnStartup > dnsCostLimit) {
            MTHNetworkTaskAdvice *advice = [[MTHNetworkTaskAdvice alloc] init];
            advice.typeId = @"DNS Cost on Startup";
            advice.level = MTHNetworkTaskAdviceLevelLow;
            advice.requestIndex = transaction.requestIndex;
            advice.adviceTitleText = @"DNS timeout during startup";
            NSMutableString *requestsDesc = [NSMutableString string];
            for (NSArray *item in context.containDNSCostRequestIndexesOnStartup) {
                [requestsDesc appendFormat:@"%@: %.0fms, ", item[0], [item[1] floatValue] * 1000];
            }
            [requestsDesc deleteCharactersInRange:NSMakeRange(requestsDesc.length - 2, 2)];
            advice.adviceDescText = [NSString stringWithFormat:@"Starting DNS in %.2fs takes %.2fs (%@), which exceeds the expected value of %.0fs. \n\nMechanism:  %@", startupDuration, context.dnsCostTotalOnStartup, requestsDesc, dnsCostLimit, transaction.requestMechanism];
            if (context.containDNSCostRequestIndexesOnStartup.count > 1) {
                advice.suggestDescText = @"It is recommended to use MTFastDNS or other method to reduce DNS time; \n\n"
                                         @"If you include DNS times for multiple different hosts, converge the domain name; \n\n"
                                         @"If you include DNS times for multiple different hosts, prioritize management; \n";
            } else {
                advice.suggestDescText = @"";
            }

            NSMutableArray *requestIndexes = [NSMutableArray array];
            [context.containDNSCostRequestIndexesOnStartup enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                if (obj[0]) {
                    [requestIndexes addObject:obj[0]];
                }
            }];
            advice.userInfo = @{kMTHNetworkTaskAdviceKeyParallelRequestIndexList : [requestIndexes copy]};

            return @[ advice ];
        }
        return nil;
    };
    return inspection;
}

NSInteger gMTHNetworkInspectionStartupTCPTimeCostLimit = 0.4; // seconds

+ (MTHNetworkTaskInspection *)startupTCPConnectionCostInspection {
    static MTHNetworkTaskInspection *inspection = nil;
    if (inspection != nil) {
        return inspection;
    }

    inspection = [[MTHNetworkTaskInspection alloc] init];
    inspection.group = @"Scheduling";
    inspection.name = @"TCP Connection Cost Inspection On Startup";
    inspection.displayName = @"Detecting long TCP shake-hand during startup";
    inspection.guide = @"";

    MTHNetworkTaskInspectionParamEntity *startupDurationParam = [[MTHNetworkTaskInspectionParamEntity alloc] init];
    startupDurationParam.displayName = @"Detecting time requests at startup";
    startupDurationParam.valueType = MTHNetworkTaskInspectionParamValueTypeFloat;
    startupDurationParam.valueUnits = @"s";
    startupDurationParam.value = @(gMTHNetworkInspectionStartupIncludingSeconds);

    MTHNetworkTaskInspectionParamEntity *tcpConnectionLimitParam = [[MTHNetworkTaskInspectionParamEntity alloc] init];
    tcpConnectionLimitParam.displayName = @"Detecting TCP time consuming during startup";
    tcpConnectionLimitParam.valueType = MTHNetworkTaskInspectionParamValueTypeFloat;
    tcpConnectionLimitParam.valueUnits = @"s";
    tcpConnectionLimitParam.value = @(gMTHNetworkInspectionStartupTCPTimeCostLimit);

    inspection.inspectCustomParams = @{
        @"StartupDuration" : startupDurationParam,
        @"TCPConnectionCostLimit" : tcpConnectionLimitParam,
    };

    inspection.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transaction, MTHNetworkTaskInspectorContext *context) {
        if (transaction.duration < 0.002f) {
            return nil;
        }

        CGFloat startupDuration = [startupDurationParam.value floatValue];
        CGFloat dnsCostLimit = [tcpConnectionLimitParam.value floatValue];

        if (([transaction.startTime timeIntervalSince1970] - [MTHawkeyeUtility appLaunchedTime]) > startupDuration) {
            return nil;
        }

        if (context.containTCPConnCostRequestIndexesOnStartup == nil) {
            context.containTCPConnCostRequestIndexesOnStartup = [NSMutableArray array];
        }

        for (NSArray *item in context.containTCPConnCostRequestIndexesOnStartup) {
            // 会多次进入，需要做去重处理
            if ([item[0] integerValue] == transaction.requestIndex) {
                return nil;
            }
        }

        NSTimeInterval tcpConnDurationCost = 0.f;
        for (MTHURLSessionTaskTransactionMetrics *metrics in transaction.taskMetrics.transactionMetrics) {
            NSTimeInterval itemTCPConnDuration = [metrics.connectEndDate timeIntervalSinceDate:metrics.connectStartDate];
            if (itemTCPConnDuration > 0.001f) {
                context.tcpConnCostTotalOnStartup += itemTCPConnDuration;
                tcpConnDurationCost += itemTCPConnDuration;
            }
        }
        if (tcpConnDurationCost > 0.001f) {
            // insert by order
            if (context.containTCPConnCostRequestIndexesOnStartup.count == 0) {
                [context.containTCPConnCostRequestIndexesOnStartup addObject:@[ @(transaction.requestIndex), @(tcpConnDurationCost) ]];
            } else {
                [context.containTCPConnCostRequestIndexesOnStartup enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                    NSInteger itemRequestIndex = [obj[0] integerValue];
                    if (itemRequestIndex < transaction.requestIndex) {
                        [context.containTCPConnCostRequestIndexesOnStartup insertObject:@[ @(transaction.requestIndex), @(tcpConnDurationCost) ] atIndex:idx];
                        *stop = YES;
                    }
                }];
            }
        }

        if (context.tcpConnCostTotalOnStartup > dnsCostLimit) {
            MTHNetworkTaskAdvice *advice = [[MTHNetworkTaskAdvice alloc] init];
            advice.typeId = @"TCP Connection Cost on Startup";
            advice.level = MTHNetworkTaskAdviceLevelLow;
            advice.requestIndex = transaction.requestIndex;
            advice.adviceTitleText = @"TCP consuming during startup";
            NSMutableString *requestsDesc = [NSMutableString string];
            for (NSArray *item in context.containTCPConnCostRequestIndexesOnStartup) {
                [requestsDesc appendFormat:@"%@: %.0fms, ", item[0], [item[1] floatValue] * 1000];
            }
            [requestsDesc deleteCharactersInRange:NSMakeRange(requestsDesc.length - 2, 2)];
            advice.adviceDescText = [NSString stringWithFormat:@"Starting TCP connection in %.2fs takes %.2fs (%@), which exceeds the expected value of %.2fs. \n\nMechanism:  %@", startupDuration, context.tcpConnCostTotalOnStartup, requestsDesc, dnsCostLimit, transaction.requestMechanism];
            if (context.containTCPConnCostRequestIndexesOnStartup.count > 1) {
                advice.suggestDescText = @"Whether multiple requests effectively utilize the features of HTTP/2, multiplexing TCP connections; \n\n"
                                         @"If you include TCP times for multiple different hosts, converge the domain name; \n\n"
                                         @"If you include TCP times for multiple different hosts, prioritize management;\n";
            } else {
                advice.suggestDescText = @"";
            }

            NSMutableArray *requestIndexes = [NSMutableArray array];
            [context.containTCPConnCostRequestIndexesOnStartup enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                if (obj[0]) {
                    [requestIndexes addObject:obj[0]];
                }
            }];
            advice.userInfo = @{kMTHNetworkTaskAdviceKeyParallelRequestIndexList : [requestIndexes copy]};

            return @[ advice ];
        }
        return nil;
    };
    return inspection;
}


+ (MTHNetworkTaskInspection *)requestTaskPriorityInspection {
    static MTHNetworkTaskInspection *inspection = nil;
    if (inspection != nil) {
        return inspection;
    }

    inspection = [[MTHNetworkTaskInspection alloc] init];
    inspection.group = @"Scheduling";
    inspection.name = @"SessioTask Priority Management Inspection";
    inspection.displayName = @"Detecting HTTP task priority management";
    inspection.guide = @"";

    MTHNetworkTaskInspectionParamEntity *queueingDurationLimitParam = [[MTHNetworkTaskInspectionParamEntity alloc] init];
    queueingDurationLimitParam.displayName = @"Filter requests with queue time less than";
    queueingDurationLimitParam.valueType = MTHNetworkTaskInspectionParamValueTypeFloat;
    queueingDurationLimitParam.valueUnits = @"s";
    queueingDurationLimitParam.value = @(0.015f);

    inspection.inspectCustomParams = @{
        @"QueueingDurationLimit" : queueingDurationLimitParam,
    };

    inspection.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transaction, MTHNetworkTaskInspectorContext *context) {
        if (!transaction.isUsingURLSession || !transaction.useURLSessionTaskMetrics) {
            return nil;
        }

        BOOL isUsingHttp2 = NO;
        if (transaction.useURLSessionTaskMetrics && transaction.taskMetrics.transactionMetrics.count) {
            isUsingHttp2 = [transaction.taskMetrics.transactionMetrics.firstObject.networkProtocolName isEqualToString:@"h2"];
        }

        // 如果 HTTP/2 & priority 已设置，预期行为
        if (isUsingHttp2 && (fabs(transaction.sessionTaskAPIUsage.taskPriority - NSURLSessionTaskPriorityDefault) > DBL_EPSILON)) {
            return nil;
        }

        // queueing duration
        MTHURLSessionTaskTransactionMetrics *metrics = [transaction.taskMetrics.transactionMetrics firstObject];
        NSTimeInterval queueingDuration = 0;
        if (metrics.domainLookupStartDate) {
            queueingDuration = [metrics.domainLookupStartDate timeIntervalSinceDate:metrics.fetchStartDate];
        } else if (metrics.connectStartDate) {
            queueingDuration = [metrics.connectStartDate timeIntervalSinceDate:metrics.fetchStartDate];
        } else if (metrics.requestStartDate) {
            queueingDuration = [metrics.requestStartDate timeIntervalSinceDate:metrics.fetchStartDate];
        }

        // only for longer than 15ms
        CGFloat queueingDurationLimit = [queueingDurationLimitParam.value floatValue];
        if (queueingDuration < queueingDurationLimit) {
            return nil;
        }

        NSArray<MTHNetworkTransaction *> *parallelTransactions = [context parallelTransactionsBefore:transaction];
        if (parallelTransactions.count <= 1) {
            return nil;
        }

        NSMutableArray *parallelTransactionsIds = [NSMutableArray array];
        [parallelTransactions enumerateObjectsUsingBlock:^(MTHNetworkTransaction *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            [parallelTransactionsIds addObject:@(obj.requestIndex)];
        }];


        MTHNetworkTaskAdvice *advice = [[MTHNetworkTaskAdvice alloc] init];
        advice.typeId = @"Unexpected Queueing Time";
        advice.requestIndex = transaction.requestIndex;
        advice.level = MTHNetworkTaskAdviceLevelLow;
        advice.adviceTitleText = [NSString stringWithFormat:@"Unexpected task queuing"];
        advice.adviceDescText = [NSString stringWithFormat:@"Unexpected task queuing time, queue waiting time for this task is %.0f ms, Unused request priority management, suspected to be blocked by concurrent network requests. \n\nMay cause critical network requests to be blocked in a complex network environment, extended request arrival time and generated Head-of-Line Blocking problem。 \n\nMechanism:  %@", queueingDuration * 1000, transaction.requestMechanism];
        advice.suggestDescText = @"Prioritize management to reduce critical requests blocked by other secondary priority requests.\n\n"
                                 @"In HTTP/1, the lack of built-in support for it, request order is advanced, and the priority is controlled by manual request queue management.\n\n"
                                 @"In HTTP/2, you can combine (reasonly manage NSURLSessionTask, domain name merging, priority control) to quickly control the priority of requests.\n";

        advice.userInfo = @{
            kMTHNetworkTaskAdviceKeyParallelRequestIndexList : [parallelTransactionsIds copy]
        };
        return @[ advice ];
    };
    return inspection;
}

+ (MTHNetworkTaskInspection *)TCPConnectionCostInspection {
    static MTHNetworkTaskInspection *inspection = nil;
    if (inspection != nil) {
        return inspection;
    }

    inspection = [[MTHNetworkTaskInspection alloc] init];
    inspection.group = @"Scheduling";
    inspection.name = @"TCP Connection Cost Inspection";
    inspection.displayName = @"Detecting time used by parallel TCP shake-hands";

    MTHNetworkTaskInspectionParamEntity *tcpConnectionDurationFilterLimitParam = [[MTHNetworkTaskInspectionParamEntity alloc] init];
    tcpConnectionDurationFilterLimitParam.displayName = @"Filter requests for tcp time less than";
    tcpConnectionDurationFilterLimitParam.valueType = MTHNetworkTaskInspectionParamValueTypeFloat;
    tcpConnectionDurationFilterLimitParam.valueUnits = @"s";
    tcpConnectionDurationFilterLimitParam.value = @(0.015f);

    inspection.inspectCustomParams = @{
        @"TCPConnectionDurationFilterLimit" : tcpConnectionDurationFilterLimitParam,
    };

    inspection.guide = @"";
    inspection.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transaction, MTHNetworkTaskInspectorContext *context) {
        if (!transaction.isUsingURLSession || !transaction.useURLSessionTaskMetrics) {
            return nil;
        }

        BOOL isUsingHttp2 = NO;
        if (transaction.useURLSessionTaskMetrics && transaction.taskMetrics.transactionMetrics.count) {
            isUsingHttp2 = [transaction.taskMetrics.transactionMetrics.firstObject.networkProtocolName isEqualToString:@"h2"];
        }

        NSTimeInterval connDuration = 0;
        for (MTHURLSessionTaskTransactionMetrics *metrics in transaction.taskMetrics.transactionMetrics) {
            connDuration += [metrics.connectEndDate timeIntervalSinceDate:metrics.connectStartDate];
        }
        if (connDuration <= 0.002f) {
            return nil;
        }

        CGFloat tcpConnectionDurationFilterLimit = [tcpConnectionDurationFilterLimitParam.value floatValue];

        NSMutableArray *containConnDurationRequestIndexs = [NSMutableArray array];
        NSArray<MTHNetworkTransaction *> *parallelTransactions = [context parallelTransactionsBefore:transaction];
        NSMutableArray *parallelTransactionRequestIndexes = [NSMutableArray array];
        if (parallelTransactions.count > 1) {
            for (MTHNetworkTransaction *trans in parallelTransactions) {

                [parallelTransactionRequestIndexes addObject:@(trans.requestIndex)];

                NSTimeInterval connDuration = 0;
                for (MTHURLSessionTaskTransactionMetrics *metrics in trans.taskMetrics.transactionMetrics) {
                    connDuration += [metrics.connectEndDate timeIntervalSinceDate:metrics.connectStartDate];
                }
                if (connDuration > tcpConnectionDurationFilterLimit) {
                    [containConnDurationRequestIndexs addObject:@[ @(trans.requestIndex), @(connDuration) ]];
                }
            }
        }

        NSMutableArray<MTHNetworkTaskAdvice *> *advices = [NSMutableArray array];
        if (containConnDurationRequestIndexs.count > 1) {
            MTHNetworkTaskAdvice *advice = [[MTHNetworkTaskAdvice alloc] init];
            advice.typeId = @"Too Many TCP Connections On Concurrency";
            advice.requestIndex = transaction.requestIndex;
            advice.level = MTHNetworkTaskAdviceLevelLow;
            advice.adviceTitleText = @"Multiple TCP on Concurrency";
            NSMutableString *requestsDesc = [NSMutableString string];
            for (NSArray *request in containConnDurationRequestIndexs) {
                [requestsDesc appendFormat:@"%@:%.0fms, ", request[0], [request[1] floatValue] * 1000.f];
            }
            [requestsDesc deleteCharactersInRange:NSMakeRange(requestsDesc.length - 2, 2)];

            advice.adviceDescText = [NSString stringWithFormat:@"There are %@ TCP (%@) in the concurrent request. \n\nMechanism:  %@", @([containConnDurationRequestIndexs count]), requestsDesc, transaction.requestMechanism];
            advice.suggestDescText = @"Concurrent TCP occur on different Hosts, whether converge the domain name";
            if (!isUsingHttp2) {
                advice.suggestDescText = [advice.suggestDescText stringByAppendingString:@"Concurrent TCP connection on the same Host, HTTP/2 is recommended"];
            }
            advice.userInfo = @{kMTHNetworkTaskAdviceKeyParallelRequestIndexList : [parallelTransactionRequestIndexes copy]};

            [advices addObject:advice];
        }

        // 很小值时，没有产生真的 tcp 连接耗时
        if (connDuration > 0.002f) {
            // 如果有包含 tcp 连接
            //    获取往前十秒内的请求，看是否有同一二级域名的请求，是否包含了 tcp 连接
            __block NSInteger preAvaiableTCPConnRequestIndex = -1;
            [context.transactions enumerateObjectsUsingBlock:^(MTHNetworkTransaction *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                if (obj.requestIndex < transaction.requestIndex && [obj.request.URL.host isEqualToString:transaction.request.URL.host]) {
                    NSTimeInterval objEndAt = [obj.startTime timeIntervalSince1970] + obj.duration;
                    NSTimeInterval diff = [transaction.startTime timeIntervalSince1970] - objEndAt;
                    if (diff >= 0.001f && diff < 10.f) {
                        preAvaiableTCPConnRequestIndex = obj.requestIndex;
                        *stop = YES;
                    }

                    if ([transaction.startTime timeIntervalSinceDate:obj.startTime] > 10.f) {
                        *stop = YES;
                    }
                }
            }];

            if (preAvaiableTCPConnRequestIndex > 0) {
                MTHNetworkTaskAdvice *advice = [[MTHNetworkTaskAdvice alloc] init];
                advice.typeId = @"TCP Connection No Reused";
                advice.requestIndex = transaction.requestIndex;
                advice.level = MTHNetworkTaskAdviceLevelLow;
                advice.adviceTitleText = @"TCP Connection is not reused";
                advice.adviceDescText = [NSString stringWithFormat:@"The request contains TCP time, within 10s, There is no TCP (%@) under the same host. \n\nMechanism:  %@", @(preAvaiableTCPConnRequestIndex), transaction.requestMechanism];
                advice.suggestDescText = @"TCP connection 10s under the same Host is reusable, check the HTTP request/response header and check if NSURLSessionTask is properly managed.";

                NSMutableArray *requests = [parallelTransactionRequestIndexes mutableCopy];
                if (![requests containsObject:@(preAvaiableTCPConnRequestIndex)]) {
                    [requests addObject:@(preAvaiableTCPConnRequestIndex)];
                }
                advice.userInfo = @{kMTHNetworkTaskAdviceKeyParallelRequestIndexList : [requests copy]};

                [advices addObject:advice];
            }
        }
        return [advices copy];
    };
    return inspection;
}

/**
 侦测应该及时取消的网络请求，如退出控制器后应该要及时取消的网络请求。
 > 目前的框架还不支持这个侦测，后续看有没有好的切入点。欢迎提 issue 或 PR, _(:з」∠)_
 */
+ (MTHNetworkTaskInspection *)shouldCancelledRequestTaskInspection {
    static MTHNetworkTaskInspection *inspection = nil;
    if (inspection != nil) {
        return inspection;
    }

    inspection = [[MTHNetworkTaskInspection alloc] init];
    inspection.group = @"Scheduling";
    inspection.name = @"Task Should Cancel In Time Inspection";
    inspection.displayName = @"Detect requests for timely cancellation";
    inspection.guide = @"";
    inspection.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transactionToInspect, MTHNetworkTaskInspectorContext *context) {

        return nil;
    };
    return inspection;
}


#pragma clang diagnostic pop

@end

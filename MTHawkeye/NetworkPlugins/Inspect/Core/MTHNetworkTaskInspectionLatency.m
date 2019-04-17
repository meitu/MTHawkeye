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


#import "MTHNetworkTaskInspectionLatency.h"
#import "MTHNetworkTaskAdvice.h"
#import "MTHNetworkTaskInspection.h"
#import "MTHNetworkTaskInspector.h"
#import "MTHNetworkTaskInspectorContext.h"
#import "MTHNetworkTransaction.h"


@implementation MTHNetworkTaskInspectionLatency

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"

+ (MTHNetworkTaskInspection *)dnsCostInspection {
    static MTHNetworkTaskInspection *inspection = nil;
    if (inspection != nil) {
        return inspection;
    }

    inspection = [[MTHNetworkTaskInspection alloc] init];
    inspection.group = @"Latency";
    inspection.name = @"DNS Cost Inspection";
    inspection.displayName = @"Detecting DNS connection time";
    inspection.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transactionToInspect, MTHNetworkTaskInspectorContext *context) {
        // 判断是否包含 URLSessionTaskMetrics
        if (!(transactionToInspect.useURLSessionTaskMetrics && transactionToInspect.taskMetrics)) {
            return nil;
        }

        // 判断总体时长 > 300ms & dns 时长占比 > 1/3
        NSTimeInterval totalCost = transactionToInspect.taskMetrics.taskInterval.duration;
        if (totalCost < 0.3f) {
            return nil;
        }

        BOOL isDNSLatencyDetected = NO;
        NSTimeInterval dnsCost = 0;
        NSURLSessionTaskMetrics *taskMetrics = transactionToInspect.taskMetrics;
        for (NSURLSessionTaskTransactionMetrics *transactionMetrics in taskMetrics.transactionMetrics) {
            dnsCost = [transactionMetrics.domainLookupEndDate timeIntervalSinceDate:transactionMetrics.domainLookupStartDate];
            if (3 * dnsCost > totalCost) {
                isDNSLatencyDetected = YES;
                break;
            }
        }

        if (isDNSLatencyDetected) {
            MTHNetworkTaskAdvice *advice = [[MTHNetworkTaskAdvice alloc] init];
            advice.typeId = @"DNSLatencyDetected";
            advice.level = MTHNetworkTaskAdviceLevelLow;
            advice.requestIndex = transactionToInspect.requestIndex;

            advice.adviceTitleText = @"DNS timeout";
            advice.adviceDescText = [NSString stringWithFormat:@"The DNS timeout (%lf) causes the overall request to take a long time. \n\nMechanism:  %@", dnsCost, transactionToInspect.requestMechanism];
            advice.suggestDescText = @"Reduce DNS time consumption with MTFastDNS or other;\n"
                                     @"If the link is reused, converge the domain name.\n"
                                     @"If unused variable HTTP/2, it is recommended to upgrade to HTTP/2 to improve connection reuse rate.\n";
            return @[ advice ];
        }
        return nil;
    };
    return inspection;
}

+ (MTHNetworkTaskInspection *)redirectRequestInspection {
    static MTHNetworkTaskInspection *inspection = nil;
    if (inspection != nil) {
        return inspection;
    }

    inspection = [[MTHNetworkTaskInspection alloc] init];
    inspection.group = @"Latency";
    inspection.name = @"Redirect Request Inspection";
    inspection.displayName = @"Detecting HTTP too much extra time cost cause of redirects";
    inspection.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transactionToInspect, MTHNetworkTaskInspectorContext *context) {
        // 判断是否包含 URLSessionTaskMetrics
        if (!(transactionToInspect.useURLSessionTaskMetrics && transactionToInspect.taskMetrics)) {
            return nil;
        }

        // 判断是否包含重定向，总时长是否 > 300ms
        NSTimeInterval totalCost = transactionToInspect.taskMetrics.taskInterval.duration;
        if (totalCost < 0.3f || transactionToInspect.taskMetrics.redirectCount == 0) {
            return nil;
        }

        BOOL isRedirectionLatencyDetected = NO;

        // 判断重定向时间最后一段之外的时间占时长 > 1/2
        NSURLSessionTaskMetrics *taskMetrics = transactionToInspect.taskMetrics;
        NSURLSessionTaskTransactionMetrics *lastTransactionMetrics = taskMetrics.transactionMetrics.lastObject;
        NSTimeInterval lastTransactionCost = [lastTransactionMetrics.responseEndDate timeIntervalSinceDate:lastTransactionMetrics.fetchStartDate];
        if (totalCost > lastTransactionCost * 2) {
            isRedirectionLatencyDetected = YES;
        }

        // 判断重定向第一段之后包含了 dns/tcp connection 时间
        if (!isRedirectionLatencyDetected) {
            BOOL isContainDNSOrTCPAfterFirstRedirection = NO;
            BOOL isAfterFirstRedirection = NO;
            for (NSURLSessionTaskTransactionMetrics *transactionMetrics in taskMetrics.transactionMetrics) {
                if (!isAfterFirstRedirection) {
                    if (![transactionMetrics.response isKindOfClass:[NSHTTPURLResponse class]]) {
                        continue;
                    }
                    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)transactionMetrics.response;
                    isAfterFirstRedirection = (3 == (NSInteger)(httpResponse.statusCode / 100));
                } else {
                    NSTimeInterval dnsCost = [transactionMetrics.domainLookupEndDate timeIntervalSinceDate:transactionMetrics.domainLookupStartDate];
                    NSTimeInterval tcpCost = [transactionMetrics.connectEndDate timeIntervalSinceDate:transactionMetrics.connectStartDate];
                    if (dnsCost > 0 || tcpCost > 0) {
                        isContainDNSOrTCPAfterFirstRedirection = YES;
                        break;
                    }
                }
            }
            if (isContainDNSOrTCPAfterFirstRedirection) {
                isRedirectionLatencyDetected = isContainDNSOrTCPAfterFirstRedirection;
            }
        }

        if (isRedirectionLatencyDetected) {
            MTHNetworkTaskAdvice *advice = [[MTHNetworkTaskAdvice alloc] init];
            advice.typeId = @"RedirectionLatencyDetected";
            advice.level = MTHNetworkTaskAdviceLevelMiddle;
            advice.requestIndex = transactionToInspect.requestIndex;

            advice.adviceTitleText = @"Timeout redirection";
            advice.adviceDescText = [NSString stringWithFormat:@"HTTP redirect causes timeout, this request contains %@ times of redirection, overall time consuming %.2fs。 \n\nMechanism:  %@", @(taskMetrics.redirectCount), transactionToInspect.duration, transactionToInspect.requestMechanism];
            advice.suggestDescText = @"If the redirect contains a different domain name, converge to the same one,  reducing the possible DNS, TCP Connection time-consuming； \n\n"
                                     @"Minimize unnecessary HTTP redirects, it can dramatically increase request timeouts in mobile";
            return @[ advice ];
        }
        return nil;
    };
    return inspection;
}


+ (MTHNetworkTaskInspection *)httpKeepAliveInspection {
    static MTHNetworkTaskInspection *inspection = nil;
    if (inspection != nil) {
        return inspection;
    }

    inspection = [[MTHNetworkTaskInspection alloc] init];
    inspection.group = @"Latency";
    inspection.name = @"HTTP KeepAlive Inspection";
    inspection.displayName = @"Detecting HTTP keep-alive not used";
    inspection.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transactionToInspect, MTHNetworkTaskInspectorContext *context) {
        // 获取 http.response. "Connection" 字段，判断为 keep-alive
        BOOL isConnectionKeepAlive = YES;

        if ([transactionToInspect.response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)transactionToInspect.response;
            NSDictionary *httpHeader = [response allHeaderFields];
            NSString *connection;
            if ((connection = httpHeader[@"Connection"]) && ![connection isEqualToString:@"keep-alive"]) {
                isConnectionKeepAlive = NO;
            }
        }

        if (!isConnectionKeepAlive) {
            MTHNetworkTaskAdvice *advice = [[MTHNetworkTaskAdvice alloc] init];
            advice.typeId = @"HTTPConnectionKeepAliveDisabled";
            advice.level = MTHNetworkTaskAdviceLevelMiddle;
            advice.requestIndex = transactionToInspect.requestIndex;

            advice.adviceTitleText = @"unused variable keep-alive";
            advice.adviceDescText = [NSString stringWithFormat:@"The keep-alive of connection is closed. \n\nMechanism:  %@", transactionToInspect.requestMechanism];
            advice.suggestDescText = @"Don't turn off keep-alive, for no special reason.\n"
                                     @"By default, keep-alive is enabled to not interrupt immediately after a request ends. The next same request in the 10 seconds, reducing unnecessary connection delays.";
            return @[ advice ];
        }
        return nil;
    };
    return inspection;
}

+ (MTHNetworkTaskInspection *)tooManyHostInspection {
    static MTHNetworkTaskInspection *inspector = nil;
    if (inspector != nil) {
        return inspector;
    }

    inspector = [[MTHNetworkTaskInspection alloc] init];
    inspector.group = @"Latency";
    inspector.name = @"Too Many Host Inspection";
    inspector.displayName = @"Detecting use too many second-level domains";
    inspector.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transactionToInspect, MTHNetworkTaskInspectorContext *context) {
        BOOL isTooManyHostDetected = NO;
        NSMutableSet<MTHTopLevelDomain *> *detectedDomains = [NSMutableSet set];

        // 收集该 transaction 中访问的每个 host
        NSMutableArray *hosts = [NSMutableArray array];
        if (transactionToInspect.useURLSessionTaskMetrics && transactionToInspect.taskMetrics) {
            NSArray *metricsArray = transactionToInspect.taskMetrics.transactionMetrics;
            for (NSURLSessionTaskTransactionMetrics *metrics in metricsArray) {
                NSString *host = metrics.request.URL.host;
                if (host.length > 0) {
                    [hosts addObject:host];
                }
            }
        } else if (transactionToInspect.request.URL.host.length > 0) {
            [hosts addObject:transactionToInspect.request.URL.host];
        }

        // 对该 transaction 中的每个 host 进行检测
        for (NSString *host in hosts) {
            // 分割一级、二级域名
            NSString *topLevelDomainString = @"com";
            NSString *firstLevelDomainComponent;
            NSString *secondLevelDomainComponent;
            NSArray<NSString *> *components = [host componentsSeparatedByString:@"."];
            NSInteger topLevelDomainIndex = [components indexOfObject:topLevelDomainString];
            if (topLevelDomainIndex > 0 && topLevelDomainIndex < components.count) {
                NSInteger firstLevelDomainIndex = topLevelDomainIndex - 1;
                firstLevelDomainComponent = components[firstLevelDomainIndex];
                if (firstLevelDomainIndex > 0) {
                    NSInteger secondLevelDomainIndex = firstLevelDomainIndex - 1;
                    secondLevelDomainComponent = components[secondLevelDomainIndex];
                }
            } else {
                // 未能检测到域名，可能使用的域名暂不支持。
                return nil;
            }

            // 保存一级、二级域名的访问记录
            if (firstLevelDomainComponent && firstLevelDomainComponent.length) {
                NSString *firstLevelDomainString = [firstLevelDomainComponent stringByAppendingFormat:@".%@", topLevelDomainString];
                MTHTopLevelDomain *firstLevelDomain = [[MTHTopLevelDomain alloc] initWithString:firstLevelDomainString];
                if (secondLevelDomainComponent && secondLevelDomainComponent.length) {
                    NSString *secondLevelDomainString = [secondLevelDomainComponent stringByAppendingFormat:@".%@", firstLevelDomainString];
                    [firstLevelDomain.secondLevelDomains addObject:secondLevelDomainString];
                }
                if (![MTHNetworkTaskInspector shared].context.topLevelDomains) {
                    [MTHNetworkTaskInspector shared].context.topLevelDomains = [NSMutableSet setWithCapacity:10];
                }

                MTHTopLevelDomain *firstLevelDomainInStorage;
                if ([[MTHNetworkTaskInspector shared].context.topLevelDomains containsObject:firstLevelDomain]) {
                    // 已存在该一级域名
                    for (MTHTopLevelDomain *domain in [MTHNetworkTaskInspector shared].context.topLevelDomains) {
                        if ([domain isEqual:firstLevelDomain]) {
                            if (firstLevelDomain.secondLevelDomains.count > 0) {
                                [domain.secondLevelDomains addObjectsFromArray:firstLevelDomain.secondLevelDomains.allObjects];
                            }
                            firstLevelDomainInStorage = domain;
                            break;
                        }
                    }
                } else {
                    // 该一级域名不存在
                    [[MTHNetworkTaskInspector shared].context.topLevelDomains addObject:firstLevelDomain];
                    firstLevelDomainInStorage = firstLevelDomain;
                }

                // 获取当前一级域名下使用到的二级域名的个数
                if (firstLevelDomainInStorage.secondLevelDomains.count > 3) {
                    isTooManyHostDetected = YES;
                    [detectedDomains addObject:firstLevelDomainInStorage];
                }
            }
        }

        if (isTooManyHostDetected) {
            MTHNetworkTaskAdvice *advice = [[MTHNetworkTaskAdvice alloc] init];
            advice.typeId = @"TooManySecondLevelDomainUsed";
            advice.level = MTHNetworkTaskAdviceLevelLow;
            advice.requestIndex = transactionToInspect.requestIndex;

            NSMutableString *descString = [NSMutableString stringWithFormat:@"There is a problem with %@ first-level domain names detected in this connection:\n", @(detectedDomains.count)];
            for (MTHTopLevelDomain *domain in detectedDomains) {
                [descString appendFormat:@"\n%@ contains %@ second-level domain, they are：\n", domain.domainString, @(domain.secondLevelDomains.count)];
                [descString appendString:domain.secondLevelDomains.description];
            }

            [descString appendFormat:@"\n\nMechanism:  %@", transactionToInspect.requestMechanism];

            advice.adviceTitleText = @"Too many second-level domain";
            advice.adviceDescText = descString;
            advice.suggestDescText = @"Too many domain are used. Converge the domain name to reduce the possible DNS, TCP Connection takes time; \n\n"
                                     @"If unused variable HTTP/2, it is recommended to upgrade to HTTP/2 to improve connection reuse rate.\n";
            return @[ advice ];
        }

        return nil;
    };
    return inspector;
}

#pragma clang diagnostic pop
#pragma clang diagnostic ignored "-Wunguarded-availability"

@end

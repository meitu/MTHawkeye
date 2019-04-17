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


#import "MTHNetworkTaskInspectionAPIUsage.h"

#import "MTHNetworkTaskAdvice.h"
#import "MTHNetworkTaskInspectorContext.h"
#import "MTHNetworkTransaction.h"
#import "MTHawkeyeHooking.h"

static BOOL MTHNetworkObserverRecordProbableBadURLEnabled = YES;
static NSArray<NSString *> *mth_nilNSURLRecordList;


@interface MTHNetworkTaskInspectionAPIUsage ()

/// 记录同一 host 的 task 是否有用了多个 session 来创建
/// @{ host : (taskSessionA(21), taskSessionB(1)), ... }
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSCountedSet<NSString *> *> *hostTasksSessions;

/// 记录所有的 session 及关联 task 次数 (暂未使用到, 几次为阈值不好设定)
@property (nonatomic, strong) NSCountedSet<NSString *> *tasksSessions;

@end


@implementation MTHNetworkTaskInspectionAPIUsage

// 此处使用 initialize 而不是 load 可能会漏掉开始时创建的几个 url，忽略不处理
+ (void)initialize {
    [self mth_networkInjectIntoNSURLCreator];
}

+ (void)mth_networkStartRecordProbableBadURL {
    MTHNetworkObserverRecordProbableBadURLEnabled = YES;

    [self mth_networkInjectIntoNSURLCreator];
}

+ (void)mth_networkStopRecordProbableBadURL {
    MTHNetworkObserverRecordProbableBadURLEnabled = NO;
}

+ (void)mth_networkInjectIntoNSURLCreator {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [NSURL class];
        SEL selector = @selector(initWithString:relativeToURL:);
        SEL swizzledSelector = [MTHawkeyeHooking swizzledSelectorForSelector:selector];

        NSURL * (^creatorSwizzleBlock)(Class, NSString *, NSURL *) = ^NSURL *(Class slf, NSString *URLString, NSURL *baseURL) {
            if (MTHNetworkObserverRecordProbableBadURLEnabled) {
                NSURL *url = ((NSURL * (*)(id, SEL, NSString *, NSURL *)) objc_msgSend)(slf, swizzledSelector, URLString, baseURL);
                if (url == nil) {
                    NSMutableArray *temp = mth_nilNSURLRecordList ? mth_nilNSURLRecordList.mutableCopy : @[].mutableCopy;
                    NSString *record = URLString;
                    if (baseURL.absoluteString.length > 0) {
                        record = [record stringByAppendingFormat:@", baseURL:%@", baseURL.absoluteString];
                    }
                    if (record) {
                        [temp addObject:record];
                    }

                    mth_nilNSURLRecordList = temp.copy;
                }
                return url;
            } else {
                NSURL *url = ((NSURL * (*)(id, SEL, NSString *, NSURL *)) objc_msgSend)(slf, swizzledSelector, URLString, baseURL);
                return url;
            }
        };
        [MTHawkeyeHooking replaceImplementationOfKnownSelector:selector onClass:class withBlock:creatorSwizzleBlock swizzledSelector:swizzledSelector];
    });
}

+ (MTHNetworkTaskInspection *)nilNSURLInspection {
    static MTHNetworkTaskInspection *inspection = nil;
    if (inspection != nil) {
        return inspection;
    }

    inspection = [[MTHNetworkTaskInspection alloc] init];
    inspection.group = @"API Usage";
    inspection.name = @"Nil NSURL Inspection";
    inspection.displayName = @"Detecting URL creation result is nil";
    inspection.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transactionToInspect, MTHNetworkTaskInspectorContext *context) {
        /*
         之前的处理直接 Hook 了 NSURL。如果创建 NSURL 返回 nil ，则将结果替换为 "" NSURL。
         但这种处理可能会影响到业务逻辑。如百度音乐 sdk 里，NSURL 做了特殊兼容，如果传入中文，会自动替换编码
         而之前的 hook 逻辑会先行处理，将 NSURL 直接返回空，造成最终请求失败。

         现改为如下逻辑：hook 时只记录原始字符串和结果，不做侵入。因现有的 Inspector 机制问题，
         mth_networkInjectIntoNSURLCreator 内拦截到的异常，直到这里才会记录到 inspector 内。
         */
        NSArray<NSString *> *copyRecords = mth_nilNSURLRecordList.copy;
        mth_nilNSURLRecordList = @[];

        NSMutableArray *advices = [NSMutableArray array];
        for (NSString *record in copyRecords) {
            MTHNetworkTaskAdvice *advice = [[MTHNetworkTaskAdvice alloc] init];
            advice.typeId = @"nil NSURL Inpsection";
            advice.level = MTHNetworkTaskAdviceLevelHigh;
            advice.adviceTitleText = @"Return nil when creating NSURL";
            advice.adviceDescText = [NSString stringWithFormat:@"Return nil when creating NSURL with %@", record];
            advice.suggestDescText = @"Please check the code";
            [advices addObject:advice];
        }

        return advices.copy;
    };
    return inspection;
}

+ (MTHNetworkTaskInspection *)unexpectedURLRequestInspection {
    static MTHNetworkTaskInspection *inspection = nil;
    if (inspection != nil) {
        return inspection;
    }

    inspection = [[MTHNetworkTaskInspection alloc] init];
    inspection.group = @"API Usage";
    inspection.name = @"Bad URL Request Inspection";
    inspection.displayName = @"Detecting URL exceptions for the request";
    inspection.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transactionToInspect, MTHNetworkTaskInspectorContext *context) {
        if (transactionToInspect.transactionState == MTHNetworkTransactionStateFailed) {
            if (transactionToInspect.error.code == NSURLErrorBadURL || transactionToInspect.error.code == NSURLErrorUnsupportedURL) {
                MTHNetworkTaskAdvice *advice = [[MTHNetworkTaskAdvice alloc] init];
                advice.typeId = @"URL unaviable Inspection";
                advice.requestIndex = transactionToInspect.requestIndex;
                advice.level = MTHNetworkTaskAdviceLevelHigh;
                advice.adviceTitleText = @"The requested URL is not available";
                NSURL *url = transactionToInspect.request.URL;
                if (url.absoluteString.length == 0) {
                    // NSURL *url = [NSURL urlWithString:@""];
                    advice.adviceDescText = [NSString stringWithFormat:@"Because the NSURL was created with a string of length 0 or containing illegal characters, this requested URL is not available. \n\nMechanism:  %@", transactionToInspect.requestMechanism];
                } else {
                    advice.adviceDescText = [NSString stringWithFormat:@"The requested URL : %@ is not available. \n\nMechanism:  %@", transactionToInspect.request.URL.absoluteString, transactionToInspect.requestMechanism];
                }
                advice.suggestDescText = [NSString stringWithFormat:@"Please check the code: %@", transactionToInspect.requestMechanism];
                return @[ advice ];
            }
        }
        return nil;
    };
    return inspection;
}

// NSURLErrorUnsupportedURL,  NSURLErrorBadURL

+ (MTHNetworkTaskInspection *)deprecatedURLConnectionInspection {
    static MTHNetworkTaskInspection *inspection = nil;
    if (inspection != nil) {
        return inspection;
    }

    inspection = [[MTHNetworkTaskInspection alloc] init];
    inspection.group = @"API Usage";
    inspection.name = @"Deprecated NSURLConnection Inspection";
    inspection.displayName = @"Detecting the use of deprecated NSURLConnection API";
    inspection.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transactionToInspect, MTHNetworkTaskInspectorContext *context) {
        if (transactionToInspect.request.URL.host.length == 0) {
            return nil;
        }

        if (!transactionToInspect.isUsingURLSession) {
            MTHNetworkTaskAdvice *advice = [[MTHNetworkTaskAdvice alloc] init];
            advice.typeId = @"URLConnectionDeprecated";
            advice.requestIndex = transactionToInspect.requestIndex;
            advice.level = MTHNetworkTaskAdviceLevelHigh;

            advice.adviceTitleText = @"Unused variable NSURLSession";
            advice.adviceDescText = [NSString stringWithFormat:@"The request uses NSURLConnection, it is recommended to use NSURLSession \n\nMechanism:  %@", transactionToInspect.requestMechanism];
            advice.suggestDescText = @"For reducing network request connection latency, NSURLSession reuses available TCP connections through shared sessions; \n\n"
                                     @"At the same time, NSURLSession started to support the HTTP/2 protocol, and enabling HTTP/2 is more conducive to subsequent network optimization operations.";

            return @[ advice ];
        } else {
            return nil;
        }
    };
    return inspection;
}

+ (MTHNetworkTaskInspection *)preferHTTP2Inspection {
    static MTHNetworkTaskInspection *inspection = nil;
    if (inspection != nil) {
        return inspection;
    }

    inspection = [[MTHNetworkTaskInspection alloc] init];
    inspection.group = @"API Usage";
    inspection.name = @"Prefer HTTP/2 Inspection";
    inspection.displayName = @"Detecting has not yet use HTTP/2";
    inspection.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transactionToInspect, MTHNetworkTaskInspectorContext *context) {
        if (transactionToInspect.request.URL.host.length == 0) {
            return nil;
        }

        if (!transactionToInspect.isUsingURLSession) {
            MTHNetworkTaskAdvice *advice = [[MTHNetworkTaskAdvice alloc] init];
            advice.typeId = @"Prefer HTTP/2";
            advice.requestIndex = transactionToInspect.requestIndex;
            advice.level = MTHNetworkTaskAdviceLevelLow;

            advice.adviceTitleText = @"Unused variable HTTP/2";
            advice.adviceDescText = [NSString stringWithFormat:@"This request has not used HTTP/2 \n\nMechanism:  %@", transactionToInspect.requestMechanism];
            advice.suggestDescText = @"It is recommended to upgrade to HTTP/2 for more optimization space:\n\n"
                                     @"A TCP connection is created, when the HTTP/2 multipling requests concurrent under the same host,yet HTTP/1.1 reduces the time consuming of multiple TCP connections; \n\n"
                                     @"For flow control、priority and server push, HTTP/2 using the binary protocol; \n\n"
                                     @"There can be one request in HTTP/1.0，and HTTP/1.1 can have multiple requests but only have one response that can cause  Head-of-line Blocking. To solve this problem, HTTP/2 supports multiplexing; \n\n"
                                     @"For reducing the size of transport packet, HTTP/2 compresses header using HPACK; \n\n"
                                     @"HTTP/2 can set the priority of the request, HTTP/1.1 can only follow the order; \n\n"
                                     @"For reducing the time-consuming travel, HTTP/2 supports server push operations; \n";

            return @[ advice ];
        } else {
            return nil;
        }
    };
    return inspection;
}

+ (MTHNetworkTaskInspection *)timeoutConfigInspection {
    static MTHNetworkTaskInspection *inspection = nil;
    if (inspection != nil) {
        return inspection;
    }

    inspection = [[MTHNetworkTaskInspection alloc] init];
    inspection.group = @"API Usage";
    inspection.name = @"Timeout Config Inspection";
    inspection.displayName = @"Detecting the use of default timeout";
    inspection.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transactionToInspect, MTHNetworkTaskInspectorContext *context) {
        if (transactionToInspect.request.URL.host.length == 0) {
            return nil;
        }

        BOOL timeoutNotSet = NO;
        if (transactionToInspect.isUsingURLSession) {
            if (transactionToInspect.request.timeoutInterval >= 60.f && transactionToInspect.sessionConfigAPIUsage.sessionConfigTimeoutIntervalForRequest >= 60.f) {
                timeoutNotSet = YES;
            }
        } else {
            if (transactionToInspect.request.timeoutInterval >= 60.f) {
                timeoutNotSet = YES;
            }
        }

        if (timeoutNotSet) {
            MTHNetworkTaskAdvice *advice = [[MTHNetworkTaskAdvice alloc] init];
            advice.typeId = @"TimeoutInterval Not Set";
            advice.requestIndex = transactionToInspect.requestIndex;
            advice.level = MTHNetworkTaskAdviceLevelMiddle;
            advice.adviceTitleText = @"No timeout is set";
            advice.adviceDescText = [NSString stringWithFormat:@"No timeoutIntervalForRequest is set, the system default value is 60s. \n\nMechanism:  %@", transactionToInspect.requestMechanism];
            advice.suggestDescText = @"TimeoutIntervalForRequest is maximum time interval between two packets. Under normal circumstances, we can set a relatively reasonable timeout to detect the status of network unavailable; \n\n"
                                     @"Because the network connection quality, it is recommended that the maximum setting is 30s, that is, if the next packet is not received for 30s, the request timeout is set; \n\n"
                                     @"If there is a detection network quality, it is recommended to make a distinction (unknown/poor: 30s, moderate: 15s, good: 8s, excellent: 5s),  see MTHNetworkStat.h; \n\n"
                                     @" TimeoutIntervalForResource is the maximum completion time for the entire task (upload/download). Default 1 week. Due to the size of the package and the queue time, there is currently no specific recommended value.\n";

            return @[ advice ];
        }

        return nil;
    };
    return inspection;
}

+ (MTHNetworkTaskInspection *)urlSessionTaskManageInspection {
    static MTHNetworkTaskInspection *inspection = nil;
    if (inspection != nil) {
        return inspection;
    }

    inspection = [[MTHNetworkTaskInspection alloc] init];
    inspection.group = @"API Usage";
    inspection.name = @"NSURLSessionTask Management Inspection";
    inspection.displayName = @"Detecting improper use of NSURLSessionTask";
    inspection.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transaction, MTHNetworkTaskInspectorContext *context) {
        if (!transaction.isUsingURLSession) {
            return nil;
        }

        NSString *host = transaction.request.URL.host;
        if (host.length == 0) {
            return nil;
        }

        NSCountedSet *curHostCountedTaskSessions;
        @synchronized(context.taskSessionsGroupbyHost) {
            if (context.taskSessionsGroupbyHost == nil) {
                context.taskSessionsGroupbyHost = [NSMutableDictionary dictionary];
            }
            if (context.countedTaskSessions == nil) {
                context.countedTaskSessions = [NSCountedSet set];
            }

            curHostCountedTaskSessions = context.taskSessionsGroupbyHost[host];
            if (curHostCountedTaskSessions == nil) {
                curHostCountedTaskSessions = [[NSCountedSet alloc] init];
                [context.taskSessionsGroupbyHost setObject:curHostCountedTaskSessions forKey:host];
            }

            if (transaction.sessionTaskAPIUsage.taskSessionIdentify) {
                // 记录每个 URLSession 创建 Task 的总数
                [context.countedTaskSessions addObject:transaction.sessionTaskAPIUsage.taskSessionIdentify];

                // 记录与当前请求同 host 的所有 task 关联的 URLSession 及其使用次数
                [curHostCountedTaskSessions addObject:transaction.sessionTaskAPIUsage.taskSessionIdentify];
            }
        }

        if (curHostCountedTaskSessions.count > 1) {
            MTHNetworkTaskAdvice *advice = [[MTHNetworkTaskAdvice alloc] init];
            advice.typeId = @"UnexpectedSessionTaskManage";
            advice.requestIndex = transaction.requestIndex;
            advice.level = MTHNetworkTaskAdviceLevelMiddle;
            advice.adviceTitleText = @"Improper use of NSURLSessionTask";

            NSMutableString *sessionsDesc = [NSMutableString string];
            [curHostCountedTaskSessions enumerateObjectsUsingBlock:^(id _Nonnull obj, BOOL *_Nonnull stop) {
                [sessionsDesc appendFormat:@"%@(%@), ", obj, @([curHostCountedTaskSessions countForObject:obj])];
            }];
            [sessionsDesc deleteCharactersInRange:NSMakeRange(sessionsDesc.length - 2, 2)];

            advice.adviceDescText = [NSString stringWithFormat:@"Multiple tasks that request host is %@ are managed by multiple NSURLSession objects(%@), rather than being managed by a unified NSURLSession object. \n\nMechanism:  %@", host, sessionsDesc, transaction.requestMechanism];
            advice.suggestDescText = @"It is recommended to use the unified NSURLSession to create a request task that manages multiple tasks, especially the same host, to improve the reuse rate of network connections and reduce the network waiting time caused by tcp reconnection.";

            return @[ advice ];
        }

        return nil;
    };
    return inspection;
}

@end

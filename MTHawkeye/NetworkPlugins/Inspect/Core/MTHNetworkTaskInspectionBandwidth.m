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


#import "MTHNetworkTaskInspectionBandwidth.h"
#import "MTHNetworkTaskAdvice.h"
#import "MTHNetworkTaskInspection.h"
#import "MTHNetworkTaskInspectorContext.h"
#import "MTHNetworkTransaction.h"


NSString *kkMTHNetworkTaskAdviceKeyDuplicatedRequestIndexList = @"kMTHNetworkTaskAdviceKeyDuplicatedRequestIndexList";

@interface MTHNetworkTaskInspectionBandwidth ()

@end


@implementation MTHNetworkTaskInspectionBandwidth

+ (MTHNetworkTaskInspection *)responseContentEncodingInspection {
    static MTHNetworkTaskInspection *inspection = nil;
    if (inspection != nil) {
        return inspection;
    }

    inspection = [[MTHNetworkTaskInspection alloc] init];
    inspection.group = @"Bandwidth";
    inspection.name = @"HTTP ContentEncoding Inspection";
    inspection.displayName = @"Detecting if response body is compressed";

    MTHNetworkTaskInspectionParamEntity *packageLimit = [[MTHNetworkTaskInspectionParamEntity alloc] init];
    packageLimit.displayName = @"Filter the package less than";
    packageLimit.valueType = MTHNetworkTaskInspectionParamValueTypeInteger;
    packageLimit.valueUnits = @"byte";
    packageLimit.value = @(512);
    inspection.inspectCustomParams = @{
        @"PackageLimit" : packageLimit
    };

    inspection.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transactionToInspect, MTHNetworkTaskInspectorContext *context) {
        if (![transactionToInspect.response isKindOfClass:[NSHTTPURLResponse class]]) {
            return nil;
        }

        // 忽略请求包较小的请求
        if (transactionToInspect.receivedDataLength < [packageLimit.value integerValue]) {
            return nil;
        }

        NSHTTPURLResponse *response = (NSHTTPURLResponse *)transactionToInspect.response;
        NSString *contentType = response.allHeaderFields[@"Content-Type"];
        if (contentType.length == 0) {
            MTHNetworkTaskAdvice *advice = [[MTHNetworkTaskAdvice alloc] init];
            advice.typeId = @"HTTP ContentEncoding";
            advice.level = MTHNetworkTaskAdviceLevelHigh;
            advice.requestIndex = transactionToInspect.requestIndex;

            advice.adviceTitleText = @"Unused variable HTTP compression";
            advice.adviceDescText = [NSString stringWithFormat:@"The Content-Type returned by the request is nil and HTTP compression is not enabled. \n\nMechanism:  %@", transactionToInspect.requestMechanism];
            advice.suggestDescText = @"It is recommended to check the HTTP Request Header to see if the Accept-Encoding is configured correctly; \n\n"
                                     @"Check if the server is configured properly，if the request is normal, it will return header should contain the expected Content-Type; \n";
            return @[ advice ];
        } else {
            return nil;
        }
    };
    return inspection;
}

+ (MTHNetworkTaskInspection *)duplicateRequestInspection {
    static MTHNetworkTaskInspection *inspection = nil;
    if (inspection != nil) {
        return inspection;
    }

    inspection = [[MTHNetworkTaskInspection alloc] init];
    inspection.group = @"Bandwidth";
    inspection.name = @"Duplicated Transactions Inspection";
    inspection.displayName = @"Detecting duplicate network transactions";
    inspection.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transaction, MTHNetworkTaskInspectorContext *context) {
        if (!transaction) {
            return nil;
        }
        if (!context.hashKeySet) {
            context.hashKeySet = [[NSMutableOrderedSet alloc] init];
        }
        if (!context.duplicatedGroups) {
            context.duplicatedGroups = [[NSMutableArray alloc] init];
        }

        if (transaction.request.URL.absoluteString.length == 0) {
            return nil;
        }

        NSString *hashKey = [context hashKeyForTransaction:transaction];
        @synchronized(context.duplicatedGroups) {
            if ([context.hashKeySet containsObject:hashKey]) {
                NSUInteger indexOfHashKey = [context.hashKeySet indexOfObject:hashKey];
                NSMutableArray<MTHNetworkTransaction *> *duplicatedTrans = [context.duplicatedGroups objectAtIndex:indexOfHashKey];
                [duplicatedTrans addObject:transaction];

                MTHNetworkTaskAdvice *advice = [[MTHNetworkTaskAdvice alloc] init];
                advice.level = MTHNetworkTaskAdviceLevelMiddle;
                advice.requestIndex = transaction.requestIndex;
                MTHNetworkTaskInspectionParamEntity *packageLimit = [[MTHNetworkTaskInspectionParamEntity alloc] init];
                packageLimit.displayName = @"Filter the package more than";
                packageLimit.valueType = MTHNetworkTaskInspectionParamValueTypeInteger;
                packageLimit.valueUnits = @"byte";
                packageLimit.value = @(512);
                inspection.inspectCustomParams = @{
                    @"PackageLimit" : packageLimit
                };

                NSMutableArray *duplicatedRequestIndexList = [NSMutableArray array];
                for (MTHNetworkTransaction *item in duplicatedTrans) {
                    [duplicatedRequestIndexList insertObject:@(item.requestIndex) atIndex:0];
                }
                NSDictionary *userInfo = @{
                    kkMTHNetworkTaskAdviceKeyDuplicatedRequestIndexList : [duplicatedRequestIndexList copy]
                };

                if (transaction.transactionState == MTHNetworkTransactionStateFailed && (transaction.error.code != NSURLErrorCancelled)) {
                    advice.typeId = @"Duplicated Failed Transactions";
                    advice.adviceTitleText = @"Multiple requests for the same network request failed";
                    advice.adviceDescText = [NSString stringWithFormat:@"Multiple requests for the same network request failed. \n\nMechanism:  %@", transaction.requestMechanism];
                    advice.suggestDescText = @"Check if the network request is normal. If the request has failed for special reasons, consider whether the request can be waived by a certain policy.";
                } else if (transaction.receivedDataLength > [packageLimit.value integerValue]) {
                    // 默认只侦测大于 512 byte 的请求包
                    advice.typeId = @"Duplicated Transactions";
                    advice.adviceTitleText = @"Duplicated request";
                    NSString *responseSize = [NSByteCountFormatter stringFromByteCount:transaction.receivedDataLength countStyle:NSByteCountFormatterCountStyleBinary];
                    advice.adviceDescText = [NSString stringWithFormat:@"There are multiple duplicate requests, and this consumes more %@ traffic. \n\nMechanism:  %@", responseSize, transaction.requestMechanism];
                    advice.suggestDescText = @"Cache some network requests directly to the local, reducing the number of subsequent requests.；\n\n"
                                             @"If data needs to be refreshed in time, it is recommended to use HTTP Cache-Control to reduce the size of the returned packet when the data is not updated; \n";
                    context.duplicatedPayloadCost += transaction.receivedDataLength;
                }

                if (advice.typeId) {
                    if (duplicatedTrans.count == 1) {
                        MTHNetworkTransaction *firstTrans = duplicatedTrans.firstObject;
                        firstTrans.repeated = YES;
                    }

                    transaction.repeated = YES;

                    advice.userInfo = userInfo;
                    return @[ advice ];
                }
            } else {
                [context.hashKeySet insertObject:hashKey atIndex:0];

                NSMutableArray *transMaybeDuplicated = [NSMutableArray arrayWithObject:transaction];
                [context.duplicatedGroups insertObject:transMaybeDuplicated atIndex:0];

                return nil;
            }
        }
        return nil;
    };
    return inspection;
}

+ (MTHNetworkTaskInspection *)responseImagePayloadInspection {
    static MTHNetworkTaskInspection *inspection = nil;
    if (inspection != nil) {
        return inspection;
    }

    inspection = [[MTHNetworkTaskInspection alloc] init];
    inspection.group = @"Bandwidth";
    inspection.name = @"Perfer Image Payload Inspection";
    inspection.displayName = @"Detecting image size and quality for optimized web requests";
    inspection.inspectHandler = ^NSArray<MTHNetworkTaskAdvice *> *(MTHNetworkTransaction *transactionToInspect, MTHNetworkTaskInspectorContext *context) {
        // 判断当前网络情况

        // 获得当前图片质量，预估压缩后的大小 http://blog.csdn.net/tomatomas/article/details/62235963

        // 根据当前网络，判断是否使用了质量太高的图片

        // 额外功能，计算使用 webP 或其他格式的文件大小

        return nil;
    };
    return inspection;
}

@end

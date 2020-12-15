//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 02/08/2017
// Created by: EuanC
//


#import "MTHNetworkTransactionsURLFilter.h"
#import "MTHNetworkTransaction.h"


@implementation MTHNetworkTransactionsURLFilter

- (instancetype)initWithParamsString:(NSString *)paramsString {
    if ((self = [super init])) {
        [self parseParamsString:paramsString];
    }
    return self;
}

- (NSString *)filterDescription {
    NSMutableString *statusDesc = [NSMutableString string];
    if (self.statusFilter != MTHNetworkTransactionStatusCodeNone) {
        if (self.statusFilter & MTHNetworkTransactionStatusCode1xx)
            [statusDesc appendString:@"1xx | "];
        if (self.statusFilter & MTHNetworkTransactionStatusCode2xx)
            [statusDesc appendString:@"2xx | "];
        if (self.statusFilter & MTHNetworkTransactionStatusCode3xx)
            [statusDesc appendString:@"3xx | "];
        if (self.statusFilter & MTHNetworkTransactionStatusCode4xx)
            [statusDesc appendString:@"4xx | "];
        if (self.statusFilter & MTHNetworkTransactionStatusCode5xx)
            [statusDesc appendString:@"5xx | "];
        if (statusDesc.length > 0) {
            [statusDesc deleteCharactersInRange:NSMakeRange(statusDesc.length - 3, 3)];
        }
        [statusDesc insertString:@"Matching Status: " atIndex:0];
    }

    NSString *duplicateOnDesc = nil;
    if (self.duplicateModeFilter) {
        duplicateOnDesc = @"Only show duplicated transactions.";
    }

    NSMutableString *hostFilterDesc = [NSMutableString string];
    if (self.hostFilter.count > 0) {
        [hostFilterDesc appendString:@"Hosts: "];
        [hostFilterDesc appendString:[self.hostFilter componentsJoinedByString:@" | "]];
    }

    NSString *urlFilterDesc;
    if (self.urlStringFilter.length > 0) {
        urlFilterDesc = [NSString stringWithFormat:@"Matching URL: %@", self.urlStringFilter];
    }

    NSMutableString *description = [NSMutableString string];
    if (statusDesc.length > 0) {
        [description appendFormat:@"%@\n", statusDesc];
    }
    if (duplicateOnDesc.length > 0) {
        [description appendFormat:@"%@\n", duplicateOnDesc];
    }
    if (hostFilterDesc.length > 0) {
        [description appendFormat:@"%@\n", hostFilterDesc];
    }
    if (urlFilterDesc.length > 0) {
        [description appendFormat:@"%@\n", urlFilterDesc];
    }

    return description.copy;
}

- (void)resetFilter {
    self.duplicateModeFilter = NO;
    self.statusFilter = MTHNetworkTransactionStatusCodeNone;
    self.urlStringFilter = nil;
}

- (void)parseParamsString:(NSString *)paramsString {
    [self resetFilter];

    NSArray *searchStringComponents = [paramsString componentsSeparatedByString:@" "];

    NSMutableArray *list = [NSMutableArray array];
    [searchStringComponents enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        if ([obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length > 0) {
            [list addObject:obj];
        }
    }];
    searchStringComponents = list.copy;

    NSString *stepKey = searchStringComponents.firstObject;
    NSInteger step = 0;
    if ([stepKey caseInsensitiveCompare:@"d"] == NSOrderedSame && paramsString.length > 1) {
        // match " d" || " d" || " d "
        self.duplicateModeFilter = YES;

        if (searchStringComponents.count > (step + 1)) {
            stepKey = searchStringComponents[step + 1];
            step += 1;
        } else {
            stepKey = nil;
        }
    }

    while (stepKey.length > 0) {
        [self parseComponents:searchStringComponents step:&step stepKey:&stepKey];
    }
}

- (BOOL)isTransactionMatchFilter:(MTHNetworkTransaction *)transaction {
    BOOL matched = YES;

    MTHNetworkTransactionStatusCode mthStatusCode = MTHNetworkTransactionStatusCodeNone;
    if (!transaction.response) {
        mthStatusCode = MTHNetworkTransactionStatusCodeNoResponse;
    } else if ([transaction.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger rspStatusCode = ((NSHTTPURLResponse *)transaction.response).statusCode;
        rspStatusCode = rspStatusCode / 100;
        mthStatusCode = 1 << (rspStatusCode - 1);
    }

    if (self.statusFilter != MTHNetworkTransactionStatusCodeNone) {
        matched = mthStatusCode & self.statusFilter;
    }

    if (self.duplicateModeFilter) {
        if (matched) {
            matched = transaction.repeated;
        }
    }

    NSString *urlStringFilter = self.urlStringFilter;
    if (urlStringFilter.length > 0) {
        if (matched) {
            matched = [[transaction.request.URL absoluteString] rangeOfString:urlStringFilter options:NSCaseInsensitiveSearch].length > 0;
        }
    }

    // while the host filter is empty, match all.
    if (self.hostFilter.count > 0 && matched) {
        NSString *host = [transaction.request.URL host];
        // 长度为 0 的 url 先匹配到任意 domain 下
        if (host.length == 0) {
            // do nothing.
        } else {
            BOOL isHostMatched = NO;
            for (NSString *careHost in self.hostFilter) {
                if ([host rangeOfString:careHost options:NSCaseInsensitiveSearch].length > 0) {
                    isHostMatched = YES;
                    break;
                }
            }
            matched = isHostMatched;
        }
    }

    return matched;
}

- (void)parseComponents:(NSArray *)searchStringComponents step:(NSInteger *)step stepKey:(NSString *__autoreleasing *)stepKey {
    if ([*stepKey caseInsensitiveCompare:@"s"] == NSOrderedSame && searchStringComponents.count > (*step + 1)) {
        NSString *statusFilterValue = searchStringComponents[*step + 1];
        NSInteger maybeInteger = [statusFilterValue integerValue];
        if (maybeInteger > 0) {
            while (maybeInteger > 9) {
                maybeInteger = maybeInteger / 10;
            }
            if (maybeInteger == 1)
                self.statusFilter = MTHNetworkTransactionStatusCode1xx;
            else if (maybeInteger == 2)
                self.statusFilter = MTHNetworkTransactionStatusCode2xx;
            else if (maybeInteger == 3)
                self.statusFilter = MTHNetworkTransactionStatusCode3xx;
            else if (maybeInteger == 4)
                self.statusFilter = MTHNetworkTransactionStatusCode4xx;
            else if (maybeInteger == 5)
                self.statusFilter = MTHNetworkTransactionStatusCode5xx;

        } else if ([statusFilterValue caseInsensitiveCompare:@"f"] == NSOrderedSame) {
            self.statusFilter = MTHNetworkTransactionStatusCodeFailed;
        }

        if (searchStringComponents.count > (*step + 2)) {
            *stepKey = searchStringComponents[*step + 2];
            *step += 2;
        } else {
            *stepKey = nil;
        }
    } else {
        self.urlStringFilter = *stepKey;
        if (searchStringComponents.count > (*step + 1)) {
            *stepKey = searchStringComponents[*step + 1];
            *step += 1;
        } else {
            *stepKey = nil;
        }
    }
}

@end

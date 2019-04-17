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


#import "MTHNetworkTaskInspectorContext.h"
#import "MTHNetworkTransaction.h"
#import "NSData+MTHawkeyeNetwork.h"

// MARK: - MTHFirstLevelDomain
@implementation MTHTopLevelDomain

- (instancetype)initWithString:(NSString *)domainString {
    if (self = [super init]) {
        _domainString = domainString;
        _secondLevelDomains = [NSMutableSet setWithCapacity:1];
    }
    return self;
}

// 利用 NSString 去重
- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[MTHTopLevelDomain class]]) {
        MTHTopLevelDomain *domain = (MTHTopLevelDomain *)object;
        return [self.domainString isEqualToString:domain.domainString];
    } else {
        return NO;
    }
}

// 利用 NSString 去重
- (NSUInteger)hash {
    return self.domainString.hash;
}

@end


// MARK: - MTHNetworkTaskInspectorContext
@interface MTHNetworkTaskInspectorContext ()

@property (nonatomic, strong) NSCache *parallelTransactionBeforeCache;
@property (readwrite, copy) NSArray<MTHNetworkTransaction *> *transactions;
@property (nonatomic, strong) NSMutableSet *existTransactionsKey;

@end


@implementation MTHNetworkTaskInspectorContext

- (instancetype)init {
    if (self = [super init]) {
        _transactions = @[];
        _existTransactionsKey = [NSMutableSet set];
    }
    return self;
}

- (void)updateContextWithTransactions:(NSArray<MTHNetworkTransaction *> *)transactions {
    NSMutableArray<MTHNetworkTransaction *> *needToAdd = @[].mutableCopy;
    [transactions enumerateObjectsUsingBlock:^(MTHNetworkTransaction *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        NSString *key = [NSString stringWithFormat:@"%@", @(obj.requestIndex)];
        if (![self.existTransactionsKey containsObject:key]) {
            [self.existTransactionsKey addObject:key];
            [needToAdd addObject:obj];
        }
    }];

    NSMutableArray<MTHNetworkTransaction *> *result = self.transactions.mutableCopy;
    [result addObjectsFromArray:needToAdd.copy];
    self.transactions = [result copy];
}

- (NSArray<MTHNetworkTransaction *> *)transactionsForRequestIndexes:(NSIndexSet *)requestIndexes {
    NSMutableArray *result = [NSMutableArray array];
    @synchronized(self.transactions) {
        // self.transactions 内有可能缺失某些 requestIndex
        NSUInteger baseIndex = [self.transactions indexOfObjectPassingTest:^BOOL(MTHNetworkTransaction *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            return obj.requestIndex == requestIndexes.firstIndex;
        }];

        if (baseIndex == NSNotFound) {
            return nil;
        }

        for (NSUInteger i = baseIndex; i != NSUIntegerMax; --i) {
            MTHNetworkTransaction *item = self.transactions[i];
            if ([requestIndexes containsIndex:item.requestIndex]) {
                [result addObject:item];
            }

            if (requestIndexes.count == result.count) {
                break;
            }
        }
    }
    return [result copy];
}

// MARK: - Duplicated Requests
- (NSString *)hashKeyForTransaction:(MTHNetworkTransaction *)transaction {
    NSString *reqKey = transaction.request.URL.absoluteString ?: @"";
    if ([transaction.cachedRequestBody length] > 0) {
        reqKey = [reqKey stringByAppendingString:[transaction.cachedRequestBody MTHNetwork_MD5HexDigest]];
    }

    NSString *key = reqKey;
    if (transaction.responseDataMD5.length > 0) {
        key = [key stringByAppendingFormat:@"+%@", transaction.responseDataMD5];
    }
    return key;
}

// MARK: - Parallel Requests
- (NSArray<MTHNetworkTransaction *> *)parallelTransactionsBefore:(MTHNetworkTransaction *)transaction {
    return [self parallelTransactionsBefore:transaction from:self.transactions];
}

- (NSArray<MTHNetworkTransaction *> *)parallelTransactionsBefore:(MTHNetworkTransaction *)transaction from:(NSArray<MTHNetworkTransaction *> *)transactions {
    if (self.parallelTransactionBeforeCache == nil) {
        self.parallelTransactionBeforeCache = [[NSCache alloc] init];
        self.parallelTransactionBeforeCache.countLimit = 5;
    }

    NSArray *parallelTransactions = [self.parallelTransactionBeforeCache objectForKey:@(transaction.requestIndex)];
    if (parallelTransactions) {
        return parallelTransactions;
    }

    NSTimeInterval transStartTime = [transaction.startTime timeIntervalSince1970];
    NSMutableArray *tempParallelTransactions = [NSMutableArray array];

    for (NSInteger i = 0; i < transactions.count; ++i) {
        MTHNetworkTransaction *item = transactions[i];
        NSTimeInterval start = [item.startTime timeIntervalSince1970];
        NSTimeInterval end = start + item.duration;
        if (end > transStartTime) {
            [tempParallelTransactions addObject:item];
        } else if (item.duration == 0) {
            // 未完成的请求
            if (item.transactionState != MTHNetworkTransactionStateFailed && item.transactionState != MTHNetworkTransactionStateFinished) {
                [tempParallelTransactions addObject:item];
            }
        }
    }

    parallelTransactions = [tempParallelTransactions copy];

    [self.parallelTransactionBeforeCache setObject:parallelTransactions forKey:@(transaction.requestIndex)];
    return parallelTransactions;
}

@end

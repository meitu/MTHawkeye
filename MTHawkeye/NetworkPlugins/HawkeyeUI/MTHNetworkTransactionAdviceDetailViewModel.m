//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2017/9/5
// Created by: 潘名扬
//


#import "MTHNetworkTransactionAdviceDetailViewModel.h"
#import "MTHNetworkTaskInspector.h"
#import "MTHNetworkTaskInspectorContext.h"
#import "MTHNetworkTransaction.h"

@interface MTHNetworkTransactionAdviceDetailViewModel ()

@property (nonatomic, copy) NSArray<NSNumber *> *currentOnViewIndexArray;

@property (nonatomic, copy) NSArray<MTHNetworkTransaction *> *networkTransactions;

@end

@implementation MTHNetworkTransactionAdviceDetailViewModel

- (instancetype)initWithRequestIndex:(NSInteger)index relatedRequestIndexes:(NSIndexSet *)indexes {
    if ((self = [super init])) {
        // 把问题所在的 request 也加入列表
        NSMutableIndexSet *combineIndexes = [indexes mutableCopy];
        [combineIndexes addIndex:index];

        _networkTransactions = [[MTHNetworkTaskInspector shared].context transactionsForRequestIndexes:combineIndexes];
        _requestIndexFocusOnCurrently = index;

        NSMutableArray *relatedIndexesArray = [NSMutableArray arrayWithCapacity:combineIndexes.count];
        [combineIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *_Nonnull stop) {
            [relatedIndexesArray addObject:[NSNumber numberWithInteger:idx]];
        }];
        _currentOnViewIndexArray = relatedIndexesArray;

        [self commonSetup];
    }
    return self;
}


/// Setup start/end time
- (void)commonSetup {
    if (self.currentOnViewIndexArray.count > 1) {
        MTHNetworkTransaction *startTr = [self transactionFromRequestIndex:[self.currentOnViewIndexArray.firstObject integerValue]];
        MTHNetworkTransaction *endTr = [self transactionFromRequestIndex:[self.currentOnViewIndexArray.lastObject integerValue]];
        self.timelineStartAt = [startTr.startTime timeIntervalSince1970];
        CGFloat onViewEndAt = [endTr.startTime timeIntervalSince1970] + endTr.duration;
        for (NSNumber *requestIndex in self.currentOnViewIndexArray) {
            MTHNetworkTransaction *item = [self transactionFromRequestIndex:requestIndex.integerValue];
            if ([item.startTime timeIntervalSince1970] + item.duration > onViewEndAt) {
                onViewEndAt = [item.startTime timeIntervalSince1970] + item.duration;
            }
        }
        for (MTHNetworkTransaction *transaction in self.networkTransactions) {
            if ([transaction.startTime timeIntervalSince1970] + transaction.duration > onViewEndAt) {
                onViewEndAt = [transaction.startTime timeIntervalSince1970] + transaction.duration;
            }
        }
        self.timelineDuration = onViewEndAt - self.timelineStartAt;
    } else {
        MTHNetworkTransaction *tr = [self transactionFromRequestIndex:self.requestIndexFocusOnCurrently];
        NSTimeInterval start = [tr.startTime timeIntervalSince1970];
        NSTimeInterval end = start + tr.duration;
        start -= tr.duration;
        end += tr.duration > 0 ? tr.duration : 0.003f;
        self.timelineStartAt = start;
        self.timelineDuration = end - start;
    }
}

- (MTHNetworkTransaction *)transactionFromRequestIndex:(NSInteger)requestIndex {
    for (MTHNetworkTransaction *transaction in self.networkTransactions) {
        if (transaction.requestIndex == requestIndex) {
            return transaction;
        }
    }
    return nil;
}

@end

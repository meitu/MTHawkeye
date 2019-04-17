//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 17/07/2017
// Created by: EuanC
//


#import "MTHNetworkMonitorViewModel.h"
#import "MTHNetworkRecorder.h"
#import "MTHNetworkRecordsStorage.h"
#import "MTHNetworkTaskAdvice.h"
#import "MTHNetworkTaskInspector.h"
#import "MTHNetworkTransactionsURLFilter.h"


@interface MTHNetworkMonitorViewModel ()

@property (nonatomic, copy) NSArray<MTHNetworkTransaction *> *networkTransactions;

@property (nonatomic, copy) NSArray<MTHNetworkTransaction *> *filteredNetworkTransactions;


@property (nonatomic, assign) NSInteger requestIndexFocusOnCurrently;
@property (nonatomic, copy) NSArray<NSNumber *> *currentOnViewIndexArray;

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<MTHNetworkTaskAdvice *> *> *advicesDict;

@end


@implementation MTHNetworkMonitorViewModel

- (instancetype)init {
    if (self = [super init]) {
        _requestIndexFocusOnCurrently = -1;
        _maxFollowingWhenFocusNotResponse = 10;
        _advicesDict = @{}.mutableCopy;
    }
    return self;
}

- (void)setNetworkTransactions:(NSArray<MTHNetworkTransaction *> *)networkTransactions {
    NSInteger preCount = self.networkTransactions.count;
    _networkTransactions = networkTransactions;

    // 新增记录，不用调整其他属性
    if (preCount >= networkTransactions.count) {
        if (preCount < self.requestIndexFocusOnCurrently) {
            self.requestIndexFocusOnCurrently = -1;
            self.currentOnViewIndexArray = @[];
        } else {
            [self focusOnTransactionWithRequestIndex:self.requestIndexFocusOnCurrently];
        }
    }
}

- (void)loadTransactionsWithInspectComoletion:(void (^)(void))inspectCompetion {
    NSArray<MTHNetworkTransaction *> *trans = [[MTHNetworkRecordsStorage shared] readNetworkTransactions];
    [self setNetworkTransactions:trans];

    if ([MTHNetworkTaskInspector isEnabled]) {
        [[MTHNetworkTaskInspector shared]
            inspectTransactions:trans
              completionHandler:^(NSDictionary<NSString *, NSArray<MTHNetworkTaskAdvice *> *> *_Nonnull inspectResult) {
                  @synchronized(self.advicesDict) {
                      [inspectResult enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSArray<MTHNetworkTaskAdvice *> *_Nonnull obj, BOOL *_Nonnull stop) {
                          self.advicesDict[key] = obj;
                      }];
                  }

                  if (inspectCompetion) {
                      inspectCompetion();
                  }
              }];
    }
}

- (void)incomeNewTransactions:(NSArray<MTHNetworkTransaction *> *)transactionsNew inspectCompletion:(void (^)(void))inspectCompetion {
    NSMutableArray *transactions = [transactionsNew mutableCopy];
    [transactions addObjectsFromArray:self.networkTransactions];
    self.networkTransactions = [transactions copy];

    if ([MTHNetworkTaskInspector isEnabled]) {
        [[MTHNetworkTaskInspector shared]
            inspectTransactions:transactionsNew
              completionHandler:^(NSDictionary<NSString *, NSArray<MTHNetworkTaskAdvice *> *> *_Nonnull inspectResult) {
                  @synchronized(self.advicesDict) {
                      [inspectResult enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSArray<MTHNetworkTaskAdvice *> *_Nonnull obj, BOOL *_Nonnull stop) {
                          self.advicesDict[key] = obj;
                      }];
                  }

                  if (inspectCompetion) {
                      inspectCompetion();
                  }
              }];
    }
}


// MARK: - Advices
- (void)setAdvices:(NSArray<MTHNetworkTaskAdvice *> *)advices forTransaction:(MTHNetworkTransaction *)transaction {
    NSString *key = [NSString stringWithFormat:@"%@", @(transaction.requestIndex)];
    @synchronized(self.advicesDict) {
        self.advicesDict[key] = advices;
    }
}

- (NSArray<MTHNetworkTaskAdvice *> *)advicesForTransaction:(MTHNetworkTransaction *)transaction {
    NSString *key = [NSString stringWithFormat:@"%@", @(transaction.requestIndex)];

    @synchronized(self.advicesDict) {
        NSArray *advices = self.advicesDict[key];
        return advices;
    }
}


// MARK: -
- (MTHNetworkTransactionsURLFilter *)getFilter {
    if (!_filter) {
        _filter = [[MTHNetworkTransactionsURLFilter alloc] initWithParamsString:(_currentSearchText ? _currentSearchText : @"")];
    }
    return _filter;
}

- (NSInteger)viewIndexFromRequestIndex:(NSInteger)requestIndex {
    NSInteger idx = self.networkTransactions.count - requestIndex;
    if (idx < 0) {
        idx = 0;
    } else if (idx >= self.networkTransactions.count) {
        idx = self.networkTransactions.count - 1;
    }

    // 可能存在一个 requestIndex 已生成，但网络请求未完成，导致 self.networkTransactions 仍不存在该 requestIndex 的情况。
    while ((idx < self.networkTransactions.count) && self.networkTransactions[idx].requestIndex != requestIndex) {
        idx++;
    }

    if (idx == self.networkTransactions.count) {
        return -1;
    } else {
        return idx;
    }
}

- (MTHNetworkTransaction *)transactionFromRequestIndex:(NSInteger)requestIndex {
    NSInteger index = [self viewIndexFromRequestIndex:requestIndex];
    if (index == -1) {
        return nil;
    }
    return self.networkTransactions[index];
}

- (void)focusOnTransactionWithRequestIndex:(NSInteger)requestIndex {
    if (requestIndex < 1) {
        return;
    }

    MTHNetworkTransaction *lastTrans = [self.networkTransactions firstObject];
    if (lastTrans && lastTrans.requestIndex < requestIndex) {
        return;
    }

    NSMutableArray *onViewIndexArray = [NSMutableArray array];

    self.requestIndexFocusOnCurrently = requestIndex;
    NSInteger viewIndex = [self viewIndexFromRequestIndex:requestIndex];
    if (viewIndex < 0 || viewIndex >= self.networkTransactions.count) {
        return;
    }

    MTHNetworkTransaction *focusOnTrans = self.networkTransactions[viewIndex];
    NSTimeInterval focusOnTransStartTime = [focusOnTrans.startTime timeIntervalSince1970];
    NSTimeInterval focusOnTransEndTime = focusOnTransStartTime + focusOnTrans.duration;
    for (NSInteger i = viewIndex + 1; i < self.networkTransactions.count; ++i) {
        MTHNetworkTransaction *item = self.networkTransactions[i];
        NSTimeInterval start = [item.startTime timeIntervalSince1970];
        NSTimeInterval end = start + item.duration;
        if (end > focusOnTransStartTime) {
            [onViewIndexArray insertObject:@(item.requestIndex) atIndex:0];
        } else if (item.duration == 0) {
            // 未完成的请求
            if (item.transactionState != MTHNetworkTransactionStateFailed && item.transactionState != MTHNetworkTransactionStateFinished) {
                [onViewIndexArray insertObject:@(item.requestIndex) atIndex:0];
            }
        } else if (viewIndex - i > 20) {
            // 最多只往回遍历 20 个请求
            break;
        }
    }

    [onViewIndexArray addObject:@(self.requestIndexFocusOnCurrently)];

    // 当前聚焦的请求未完成
    if (focusOnTrans.transactionState != MTHNetworkTransactionStateFinished && focusOnTrans.transactionState != MTHNetworkTransactionStateFailed) {
        for (NSInteger i = viewIndex - 1; i >= 0; --i) {
            [onViewIndexArray addObject:@([self.networkTransactions[i] requestIndex])];
            if (i - viewIndex >= self.maxFollowingWhenFocusNotResponse) {
                break;
            }
        }
    } else {
        for (NSInteger i = viewIndex - 1; i >= 0; --i) {
            MTHNetworkTransaction *item = self.networkTransactions[i];
            NSTimeInterval start = [item.startTime timeIntervalSince1970];
            if (start < focusOnTransEndTime) {
                [onViewIndexArray addObject:@([self.networkTransactions[i] requestIndex])];
            }
            if (i - viewIndex >= 20) {
                break;
            }
        }
    }

    self.currentOnViewIndexArray = [onViewIndexArray copy];

    [self setupWaterfallTimelineRange];
}


/**
 设置 waterfall 视图的时间区间

 此处会对长耗时的失败请求做特殊处理，以减少最终显示时将正常请求的矩形过度压缩的问题
 */
- (void)setupWaterfallTimelineRange {
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

    // when the total duration is more than 4 times of focusTransaction,
    // put the focusTransaction in the center, and crop head and tail.
    MTHNetworkTransaction *focusTr = [self transactionFromRequestIndex:self.requestIndexFocusOnCurrently];
    NSTimeInterval focusTrDuration = focusTr.duration;
    if (self.timelineDuration > focusTr.duration * 5) {
        self.timelineStartAt = [focusTr.startTime timeIntervalSince1970] - focusTr.duration * 2.f;
        self.timelineDuration = focusTr.duration * 5.f;
    }
}

// 查找当前 waterfall 视图上的第一个请求（尽量过滤长耗时失败的请求，用以减少对正常请求的比例影响）
- (MTHNetworkTransaction *)startTransactionPreferNotFailedOnCurrentView {
    for (NSNumber *indexObj in self.currentOnViewIndexArray) {
        MTHNetworkTransaction *item = [self transactionFromRequestIndex:[indexObj integerValue]];
        if (item.transactionState != MTHNetworkTransactionStateFailed || item.duration < 1.f) {
            return item;
        }
    }

    return [self transactionFromRequestIndex:[self.currentOnViewIndexArray.firstObject integerValue]];
}

// 查找当前 waterfall 视图上的最后一个请求（尽量过滤长耗时失败的请求，用以减少对正常请求的比例影响）
- (MTHNetworkTransaction *)endTransactionPreferNotFailedOnCurrentView {
    for (NSNumber *indexObj in [self.currentOnViewIndexArray.reverseObjectEnumerator allObjects]) {
        MTHNetworkTransaction *item = [self transactionFromRequestIndex:[indexObj integerValue]];
        if (item.transactionState != MTHNetworkTransactionStateFailed || item.duration < 1.f) {
            return item;
        }
    }

    return [self transactionFromRequestIndex:[self.currentOnViewIndexArray.lastObject integerValue]];
}

// MARK: - filter
- (void)updateSearchResultsWithText:(NSString *)searchString completion:(void (^)(void))completion {
    self.currentSearchText = searchString;
    if (!self.filter) {
        MTHNetworkTransactionsURLFilter *filter = [[MTHNetworkTransactionsURLFilter alloc] initWithParamsString:searchString];
        self.filter = filter;
    }
    MTHNetworkTransactionsURLFilter *filter = self.filter;
    [filter parseParamsString:searchString];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *filteredNetworkTransactions = [self.networkTransactions filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(MTHNetworkTransaction *transaction, NSDictionary *bindings) {
            return [filter isTransactionMatchFilter:transaction];
        }]];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.currentSearchText isEqualToString:searchString]) {
                self.filteredNetworkTransactions = filteredNetworkTransactions;
                if (completion) {
                    completion();
                }
            }
        });
    });
}

@end

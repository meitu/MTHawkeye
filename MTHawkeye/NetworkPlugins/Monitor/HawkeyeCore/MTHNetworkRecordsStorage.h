//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/24
// Created by: EuanC
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MTHNetworkTransaction;

@interface MTHNetworkRecordsStorage : NSObject

+ (instancetype)shared;

- (void)storeNetworkTransaction:(MTHNetworkTransaction *)transaction;
- (NSArray<MTHNetworkTransaction *> *)readNetworkTransactions;

+ (void)trimCurrentSessionLargeRecordsToCost:(NSUInteger)costLimitInMB;

// MARK: -
+ (NSUInteger)getCurrentSessionRecordsFileSize;
+ (NSUInteger)getHistorySessionRecordsFileSize;

+ (void)removeAllCurrentSessionRecords;
+ (void)removeAllHistorySessionRecords;

@end

NS_ASSUME_NONNULL_END

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


#import <Foundation/Foundation.h>
#import "MTHNetworkTransaction.h"


NS_ASSUME_NONNULL_BEGIN


@class MTHNetworkTaskInspectionWithResult;

@interface MTHNetworkTransactionsURLFilter : NSObject

@property (nonatomic, assign) MTHNetworkTransactionStatusCode statusFilter;
@property (nonatomic, assign) BOOL duplicateModeFilter;
@property (nonatomic, copy) NSString *urlStringFilter;       /**< 过滤特定 URL 整串 */
@property (nonatomic, copy) NSArray<NSString *> *hostFilter; /**< 过滤特定 host */

- (instancetype)initWithParamsString:(NSString *)param;

- (BOOL)isTransactionMatchFilter:(MTHNetworkTransaction *)transaction;
- (void)parseParamsString:(NSString *)paramsString;

- (NSString *)filterDescription;

@end


NS_ASSUME_NONNULL_END

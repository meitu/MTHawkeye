//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 24/08/2017
// Created by: EuanC
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MTHNetworkTaskAdviceLevel) {
    MTHNetworkTaskAdviceLevelHigh = 0,
    MTHNetworkTaskAdviceLevelMiddle = 1,
    MTHNetworkTaskAdviceLevelLow = 2,
};

@interface MTHNetworkTaskAdvice : NSObject

@property (nonatomic, copy) NSString *typeId; // 标记问题类型，不同 Transaction 里的 advice 之间同 typeId 的可以聚合为一组
@property (nonatomic, assign) MTHNetworkTaskAdviceLevel level;

@property (nonatomic, assign) NSInteger requestIndex;

@property (nonatomic, copy, nullable) NSString *adviceTitleText; // the title of advice
@property (nonatomic, copy, nullable) NSString *adviceDescText;  // advice detail
@property (nonatomic, copy, nullable) NSString *suggestDescText; // suggestion detail

@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSArray<NSNumber *> *> *userInfo; // 可用于存放关联的请求等信息 [key:string , value: [Int]]

- (NSString *)levelText;

@end

NS_ASSUME_NONNULL_END

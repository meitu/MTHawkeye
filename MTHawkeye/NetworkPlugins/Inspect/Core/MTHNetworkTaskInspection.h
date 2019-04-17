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


@class MTHNetworkTaskAdvice;
@class MTHNetworkTransaction;
@class MTHNetworkTaskInspectorContext;

typedef NSArray<MTHNetworkTaskAdvice *> *_Nullable (^MTHNetworkTaskInspectHandler)(MTHNetworkTransaction *transactionToInspect, MTHNetworkTaskInspectorContext *context);

typedef NS_ENUM(NSInteger, MTHNetworkTaskInspectionParamValueType) {
    MTHNetworkTaskInspectionParamValueTypeNone = 0,
    MTHNetworkTaskInspectionParamValueTypeInteger = 1,
    MTHNetworkTaskInspectionParamValueTypeFloat = 2,
    MTHNetworkTaskInspectionParamValueTypeBoolean = 3,
};

@class MTHNetworkTaskInspectionParamEntity;

/**
 网络请求任务侦测项
 */
@interface MTHNetworkTaskInspection : NSObject

@property (nonatomic, copy) NSString *group;           // 分组名称 (APIUsage, Bandwidth, Lantency, Scheduling ...).
@property (nonatomic, copy) NSString *name;            // 命名
@property (nonatomic, copy) NSString *displayName;     // 显示名称
@property (nonatomic, copy, nullable) NSString *guide; // 侦测说明，可用于开关界面上的说明

@property (nonatomic, assign) BOOL enabled; // 是否开启

@property (nonatomic, copy) MTHNetworkTaskInspectHandler inspectHandler;

/**
 用于传入非默认的侦测参数，详见内置 inspect 的使用
 */
@property (nonatomic, copy) NSDictionary<NSString *, MTHNetworkTaskInspectionParamEntity *> *inspectCustomParams;

@end


/**
 侦测项单个配置参数
 */
@interface MTHNetworkTaskInspectionParamEntity : NSObject

@property (nonatomic, copy) NSString *displayName;                              // 配置参数的显示名称
@property (nonatomic, strong) id value;                                         // 配置参数的值
@property (nonatomic, assign) MTHNetworkTaskInspectionParamValueType valueType; // 配置参数的数值类型
@property (nonatomic, copy, nullable) NSString *valueUnits;                     // 配置参数的显示单位

@end


NS_ASSUME_NONNULL_END

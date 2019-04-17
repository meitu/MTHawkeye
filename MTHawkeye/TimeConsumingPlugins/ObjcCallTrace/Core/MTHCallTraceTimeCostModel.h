//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 01/11/2017
// Created by: EuanC
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTHCallTraceTimeCostModel : NSObject

@property (nonatomic, copy) NSString *className;  /**< ObjC class name */
@property (nonatomic, copy) NSString *methodName; /**< Objc method name */
@property (nonatomic, assign) BOOL isClassMethod;
@property (nonatomic, assign) NSTimeInterval timeCostInMS;                            /**< cost in millisecond */
@property (nonatomic, assign) NSTimeInterval eventTime;                               /**< happen at */
@property (nonatomic, assign) NSUInteger callDepth;                                   /**< depth from top */
@property (nonatomic, copy, nullable) NSArray<MTHCallTraceTimeCostModel *> *subCosts; // 子调用

@end

NS_ASSUME_NONNULL_END

//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 8/16/19
// Created by: tripleCC
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTObjectStrongReferenceCollector : NSObject
@property (weak, nonatomic, readonly) id object;
@property (copy, nonatomic, readonly) NSArray *strongReferences;
@property (copy, nonatomic) BOOL (^stopForClsBlock)(Class cls);
- (instancetype)initWithObject:(id)object;
@end

NS_ASSUME_NONNULL_END

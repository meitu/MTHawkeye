//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/10
// Created by: EuanC
//


#import <Foundation/Foundation.h>
#import "MTHLivingObjectShadow.h"

NS_ASSUME_NONNULL_BEGIN


/**
 living instance info. when instance released, the property instance will be nil.
 */
@interface MTHLivingObjectInfo : NSObject

@property (nonatomic, readonly, weak, nullable) id instance;

@property (nonatomic, readonly) NSString *preHolderName;
@property (nonatomic, readonly) NSTimeInterval recordTime;
@property (nonatomic, readonly) BOOL theHodlerIsNotOwner;
@property (nonatomic, readonly) BOOL isSingleton;

@end


/**
 Group living instance by class. (for assemble and storage).
 */
@interface MTHLivingObjectGroupInClass : NSObject

@property (nonatomic, copy, readonly) NSString *className;
@property (nonatomic, readonly) NSArray<MTHLivingObjectInfo *> *aliveInstances;

@property (nonatomic, assign) NSInteger detectedCount;
@property (nonatomic, assign) NSInteger aliveInstanceCount;

- (void)addMayLeakedInstance:(MTHLivingObjectShadow *)objShadow
                  completion:(void (^)(MTHLivingObjectInfo *theAliveInstance))completion;

@end


/**
 Group living instance by shadow cast action. (for viewing)
 */
@interface MTHLivingObjectGroupInTrigger : NSObject

@property (nonatomic, strong) MTHLivingObjectShadowTrigger *trigger;

@property (nonatomic, copy) NSArray<MTHLivingObjectInfo *> *detectedInstances;
@property (nonatomic, assign) NSInteger aliveInstanceCount;

@end


NS_ASSUME_NONNULL_END

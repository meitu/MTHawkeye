//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/6
// Created by: EuanC
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define MTHLivingObjectSnifferPerformanceTestEnabled 0

#ifdef MTHLivingObjectSnifferPerformanceTestEnabled
#define _InternalMTHLivingObjectSnifferPerformanceTestEnabled MTHLivingObjectSnifferPerformanceTestEnabled
#else
#define _InternalMTHLivingObjectSnifferPerformanceTestEnabled NO
#endif

extern BOOL mthawkeye_livingObjectsSnifferNSFoundationContainerEnabled;

@class MTHLivingObjectShadow;
@class MTHLivingObjectShadowPackage;

@protocol MTHLivingObjectShadowing <NSObject>

- (BOOL)mth_castShadowOver:(MTHLivingObjectShadowPackage *)shadowPackage withLight:(nullable id)light;

- (MTHLivingObjectShadow *)mth_castShadowFromLight:(nullable id)light;

- (BOOL)mth_shouldObjectAlive;

@end


@interface MTHLivingObjectShadow : NSObject

@property (nonatomic, weak, nullable) id target;           // when the target release, the shadow itself will released.
@property (nonatomic, weak, nullable) id light;            // when the light source 'released', the target should release.
@property (nonatomic, copy, nullable) NSString *lightName; // the class name of the light.
@property (nonatomic, assign) NSTimeInterval createAt;     // shadow create time.

- (instancetype)initWithTarget:(id)object;

@end


@interface MTHLivingObjectShadowPackage : NSObject

@property (nonatomic, readonly) NSHashTable<MTHLivingObjectShadow *> *shadows;

- (BOOL)addShadow:(MTHLivingObjectShadow *)shadow;

@end



/****************************************************************************/
#pragma mark -

typedef enum : NSUInteger {
    MTHLivingObjectShadowTriggerTypeUnknown = 0,
    MTHLivingObjectShadowTriggerTypeViewController = 1,
    MTHLivingObjectShadowTriggerTypeView = 2,
} MTHLivingObjectShadowTriggerType;

/**
 Keep who collect the shadow, would be useful to restore how shadow create.
 */
@interface MTHLivingObjectShadowTrigger : NSObject

- (instancetype)initWithType:(MTHLivingObjectShadowTriggerType)type;
- (instancetype)initWithDictionary:(NSDictionary *)dict;

- (NSDictionary *)inDictionary;

@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, assign) NSTimeInterval endTime;

@property (nonatomic, assign) MTHLivingObjectShadowTriggerType type;
@property (nonatomic, copy) NSString *name;

/**
 for ViewControllers that has childViewControllers, the trigger would be parent.
 we keep the child info under nameExtra.
 form in "childA,childB,childC".
 */
@property (nonatomic, copy) NSString *nameExtra;

@end


NS_ASSUME_NONNULL_END

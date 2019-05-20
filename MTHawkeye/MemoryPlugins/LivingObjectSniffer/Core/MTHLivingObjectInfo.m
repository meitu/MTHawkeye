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


#import "MTHLivingObjectInfo.h"


@interface MTHLivingObjectInfo ()

@property (nonatomic, weak, readwrite) id instance;
@property (nonatomic, copy) NSString *preHolderName;
@property (nonatomic, assign) NSTimeInterval recordTime;

@property (nonatomic, assign) BOOL theHodlerIsNotOwner;
@property (nonatomic, assign) BOOL isSingleton;

@end

@implementation MTHLivingObjectInfo

@end


/****************************************************************************/
#pragma mark -


@interface MTHLivingObjectGroupInClass ()

@property (nonatomic, copy) NSString *className;

@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *instanceKeySet;                             // 排序的 instance pointer string.
@property (nonatomic, strong) NSMutableDictionary<NSString *, MTHLivingObjectInfo *> *instanceCounterDict; // key 为 instance pointer string, value 为


@end

@implementation MTHLivingObjectGroupInClass

- (instancetype)init {
    if ((self = [super init])) {
        _instanceKeySet = [[NSMutableOrderedSet alloc] init];
        _instanceCounterDict = [NSMutableDictionary dictionary];
        _detectedCount = 0;
    }
    return self;
}

- (void)addMayLeakedInstance:(MTHLivingObjectShadow *)objShadow
                  completion:(void (^)(MTHLivingObjectInfo *theAliveInstance))completion {
    id instance = objShadow.target;
    if (self.className.length == 0) {
        self.className = NSStringFromClass([instance class]);
    }

    BOOL isSingleton = NO;
    NSString *instanceKey = [[self class] keyForInstance:instance];

    MTHLivingObjectInfo *instanceCounter = nil;
    @synchronized(self.instanceKeySet) {
        // already detected once.
        if ([self.instanceKeySet containsObject:instanceKey]) {
            instanceCounter = self.instanceCounterDict[instanceKey];
            if (isSingleton) {
                instanceCounter.isSingleton = YES;
            }

            // for UIView, CALayer. we make it sample, a living is a living, ignore shared.
            if (![instance isKindOfClass:[UIView class]] && ![instance isKindOfClass:[CALayer class]]) {
                instanceCounter.theHodlerIsNotOwner = YES;
            }
        } else {
            [self.instanceKeySet insertObject:instanceKey atIndex:0];
            instanceCounter = [[MTHLivingObjectInfo alloc] init];
            instanceCounter.instance = instance;
            instanceCounter.preHolderName = objShadow.lightName;
            instanceCounter.recordTime = objShadow.createAt;
            [self.instanceCounterDict setObject:instanceCounter forKey:instanceKey];
        }
    }

    self.detectedCount++;

    if (completion) {
        completion(instanceCounter);
    }
}

- (NSArray<MTHLivingObjectInfo *> *)aliveInstances {
    NSMutableArray<MTHLivingObjectInfo *> *list = [NSMutableArray array];
    @synchronized(self.instanceKeySet) {
        for (NSString *key in self.instanceKeySet) {
            MTHLivingObjectInfo *inst = self.instanceCounterDict[key];
            if (inst.instance) {
                [list addObject:inst];
            }
        }
    }
    return list;
}

+ (NSString *)keyForInstance:(id)object {
    return [NSString stringWithFormat:@"%p", object];
}

- (NSInteger)aliveInstanceCount {
    NSInteger count = 0;
    for (MTHLivingObjectInfo *inst in self.aliveInstances) {
        count += inst.instance ? 1 : 0;
    }
    return count;
}

@end


/****************************************************************************/
#pragma mark -

@implementation MTHLivingObjectGroupInTrigger

@end

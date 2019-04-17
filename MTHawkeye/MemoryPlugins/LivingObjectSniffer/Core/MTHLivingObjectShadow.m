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


#import "MTHLivingObjectShadow.h"
#import <MTHawkeye/MTHawkeyeLogMacros.h>


BOOL mthawkeye_livingObjectsSnifferNSFoundationContainerEnabled = NO;

@implementation MTHLivingObjectShadow

- (instancetype)initWithTarget:(id)object {
    if (self = [super init]) {
        _target = object;
        _createAt = CFAbsoluteTimeGetCurrent();
    }
    return self;
}

@end


@interface MTHLivingObjectShadowPackage ()

@property (nonatomic, copy, readwrite) NSHashTable<MTHLivingObjectShadow *> *shadows;

@end


@implementation MTHLivingObjectShadowPackage : NSObject

- (BOOL)addShadow:(MTHLivingObjectShadow *)shadow {
#ifdef MTHLivingObjectDebug
    MTHLogDebug(@" add shadow: %@: %@", [shadow.target class], shadow.target);
#endif
    if ([self.shadows containsObject:shadow])
        return NO;

    [self.shadows addObject:shadow];
    return YES;
}

- (NSHashTable<MTHLivingObjectShadow *> *)shadows {
    if (_shadows == nil) {
        _shadows = [NSHashTable weakObjectsHashTable];
    }
    return _shadows;
}

@end


@implementation MTHLivingObjectShadowTrigger

- (instancetype)initWithType:(MTHLivingObjectShadowTriggerType)type {
    if (self = [super init]) {
        _type = type;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    NSInteger typeI = [dict[@"type"] integerValue];
    MTHLivingObjectShadowTriggerType type;
    if (typeI == 1)
        type = MTHLivingObjectShadowTriggerTypeViewController;
    else if (typeI == 2)
        type = MTHLivingObjectShadowTriggerTypeView;
    else
        type = MTHLivingObjectShadowTriggerTypeUnknown;

    if (self = [self initWithType:type]) {
        _startTime = [dict[@"start"] doubleValue];
        _endTime = [dict[@"end"] doubleValue];
        _name = dict[@"name"];
        _nameExtra = dict[@"name_extra"];
    }
    return self;
}

- (NSDictionary *)inDictionary {
    NSMutableDictionary *dict = @{}.mutableCopy;
    dict[@"type"] = [NSString stringWithFormat:@"%@", @(self.type)];
    dict[@"start"] = [NSString stringWithFormat:@"%@", @(self.startTime)];
    dict[@"end"] = [NSString stringWithFormat:@"%@", @(self.endTime)];
    dict[@"name"] = self.name ?: @"";
    if (self.nameExtra.length > 0)
        dict[@"name_extra"] = self.nameExtra;
    return dict.copy;
}

@end

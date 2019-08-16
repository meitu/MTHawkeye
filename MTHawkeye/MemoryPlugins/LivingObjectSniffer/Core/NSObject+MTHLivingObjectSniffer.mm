//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 29/06/2017
// Created by: EuanC
//


#import <objc/runtime.h>
#import "MTHLivingObjectInfo.h"
#import "MTHawkeyeLogMacros.h"
#import "MTHawkeyePropertyBox.h"
#import "MTHLivingObjectReferenceCollector.h"
#import "NSObject+MTHLivingObjectSniffer.h"

#import <MTHawkeye/MTHawkeyeDyldImagesUtils.h>
#import <MTHawkeye/MTHawkeyeSignPosts.h>
#import <string>
#import <vector>


@implementation NSObject (MTHLivingObjectSniffer)


- (void)setMth_livingObjectShadow:(MTHLivingObjectShadow *)shadow {
    objc_setAssociatedObject(self, @selector(mth_livingObjectShadow), shadow, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (MTHLivingObjectShadow *)mth_livingObjectShadow {
    id shadow = objc_getAssociatedObject(self, @selector(mth_livingObjectShadow));
    return shadow;
}

- (BOOL)mth_castShadowOver:(MTHLivingObjectShadowPackage *)shadowPackage withLight:(nullable id)light {
#ifdef MTHLivingObjectDebug
    MTHLogDebug(@" mth_castShadowOver: %@:%@", [self class], self);
#endif
    if (object_isClass(self) || mtha_addr_is_in_sys_libraries((vm_address_t)self.class) || [self isKindOfClass:[MTHLivingObjectGroupInClass class]]) {
        return NO;
    }

    MTHLivingObjectShadow *selfShadow = [self mth_castShadowFromLight:light];
    if (![shadowPackage addShadow:selfShadow]) {
        // avoid infinite loop call
        return NO;
    }

    MTHSignpostStart(511);

    MTHLivingObjectReferenceCollector *collector = [[MTHLivingObjectReferenceCollector alloc] initWithObject:self];
    collector.stopForClsBlock = ^BOOL(Class  _Nonnull __unsafe_unretained cls) {
        return mtha_addr_is_in_sys_libraries((vm_address_t)cls);
    };
    
    NSArray *subObjects = collector.strongReferences;

    MTHSignpostEnd(511);

    [subObjects enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        [obj mth_castShadowOver:shadowPackage withLight:self];
    }];

    return YES;
}

- (MTHLivingObjectShadow *)mth_castShadowFromLight:(nullable id)light {
    if ([self mth_livingObjectShadow] != nil) {
        MTHLivingObjectShadow *shadow = [self mth_livingObjectShadow];
        if (shadow.light == nil && light != nil) {
            shadow.light = light;
            Class cls = [light class];
            if (cls) {
                shadow.lightName = NSStringFromClass(cls);
            }
        }
        return shadow;
    }

    // skip system framework classes
    if (mtha_addr_is_in_sys_libraries((vm_address_t)self.class)) {
        return nil;
    }

    MTHLivingObjectShadow *shadow = [[MTHLivingObjectShadow alloc] initWithTarget:self];
    if (light) {
        shadow.light = light;
        shadow.lightName = NSStringFromClass([light class]);
    }
    [self setMth_livingObjectShadow:shadow];
    return shadow;
}

- (BOOL)mth_shouldObjectAlive {
    BOOL shouldAlive = YES;
    if (self.mth_livingObjectShadow.light == nil) {
        shouldAlive = NO;
    }
    return shouldAlive;
}

@end

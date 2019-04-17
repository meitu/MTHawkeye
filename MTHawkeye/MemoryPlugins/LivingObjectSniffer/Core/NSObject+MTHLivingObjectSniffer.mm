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
    if (mtha_addr_is_in_sys_libraries((vm_address_t)self.class) || [self isKindOfClass:[MTHLivingObjectGroupInClass class]]) {
        return NO;
    }

    MTHLivingObjectShadow *selfShadow = [self mth_castShadowFromLight:light];
    if (![shadowPackage addShadow:selfShadow]) {
        // avoid infinite loop call
        return NO;
    }

    MTHSignpostStart(511);

    NSMutableArray *subObjects = @[].mutableCopy;

    Class curLevelClass = self.class;
    while (curLevelClass) {
        // skip not our own classes
        if (mtha_addr_is_in_sys_libraries((vm_address_t)curLevelClass))
            break;

        unsigned int i, count = 0;
        objc_property_t *properties = class_copyPropertyList(curLevelClass, &count);
        for (i = 0; i < count; i++) {
            objc_property_t property = properties[i];
            mthawkeye_property_box property_box = mthawkeye_extract_property(property);
            if ((!property_box.is_copy && !property_box.is_strong) || property_box.ivar_name == NULL || property_box.ivar_name[0] == '\0')
                continue;

            @try {
                Ivar ivar = class_getInstanceVariable([self class], property_box.ivar_name);
                const char *type = ivar_getTypeEncoding(ivar);
                if (type != NULL && type[0] != '@') {
                    continue;
                }
                id obj = object_getIvar(self, ivar);
                if (!obj) {
                    continue;
                }
                [subObjects addObject:obj];
            } @catch (NSException *e) {
            }
        }
        free(properties);

        curLevelClass = curLevelClass.superclass;
    }

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
            shadow.lightName = NSStringFromClass([light class]);
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

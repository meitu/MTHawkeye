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


#import "MTHLivingObjectShadow.h"
#import "MTHLivingObjectSniffService.h"
#import "MTH_RSSwizzle.h"
#import "NSObject+MTHLivingObjectSniffer.h"
#import "UIView+MTHLivingObjectSniffer.h"
#import "UIViewController+MTHLivingObjectSniffer.h"

#import <MTHawkeye/MTHawkeyeDyldImagesUtils.h>


@implementation UIView (MTHLivingObjectSniffer)

+ (void)mthl_livingObjectSnifferSetup {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        static const void *key1 = &key1;
        SEL selector1 = @selector(didMoveToSuperview);
        Class classToSwizzle = [UIView class];
        [MTH_RSSwizzle
            swizzleInstanceMethod:selector1
                          inClass:classToSwizzle
                    newImpFactory:^id(MTH_RSSwizzleInfo *swizzleInfo) {
                        return ^void(__unsafe_unretained id self) {
                            [self mthl_DidMoveToSuperview];

                            void (*originalIMP)(__unsafe_unretained id, SEL);
                            originalIMP = (__typeof(originalIMP))[swizzleInfo getOriginalImplementation];
                            originalIMP(self, selector1);
                        };
                    }
                             mode:MTH_RSSwizzleModeOncePerClassAndSuperclasses
                              key:key1];

        static const void *key2 = &key2;
        SEL selector2 = @selector(didMoveToWindow);
        [MTH_RSSwizzle
            swizzleInstanceMethod:selector2
                          inClass:classToSwizzle
                    newImpFactory:^id(MTH_RSSwizzleInfo *swizzleInfo) {
                        return ^void(__unsafe_unretained id self) {
                            [self mthl_DidMoveToWindow];

                            void (*originalIMP)(__unsafe_unretained id, SEL);
                            originalIMP = (__typeof(originalIMP))[swizzleInfo getOriginalImplementation];
                            originalIMP(self, selector2);
                        };
                    }
                             mode:MTH_RSSwizzleModeOncePerClassAndSuperclasses
                              key:key2];
    });
}

- (void)mthl_DidMoveToWindow {
    // ignore system views.
    if (mtha_addr_is_in_sys_libraries((vm_address_t)self.class))
        return;

    if (![self superview] && !self.window) {
        [[MTHLivingObjectSniffService shared].sniffer sniffLivingViewShadow:[self mth_castShadowFromLight:nil]];
    }
}

- (void)mthl_DidMoveToSuperview {
    // ignore system views.
    if (mtha_addr_is_in_sys_libraries((vm_address_t)self.class))
        return;

    BOOL hasAliveParent = NO;
    if ([self superview]) {
        hasAliveParent = YES;
    } else {
        hasAliveParent = NO;
    }

    if (!hasAliveParent) {
        [[MTHLivingObjectSniffService shared].sniffer sniffLivingViewShadow:[self mth_castShadowFromLight:nil]];
    }
}

// MARK: - MTHLivingObjectShadowing

- (MTHLivingObjectShadow *)mth_castShadowFromLight:(nullable id)light {
    return [super mth_castShadowFromLight:light];
}

- (void)mth_castShadowOver:(MTHLivingObjectShadowPackage *)shadowPackage withLight:(nullable id)light {
    [super mth_castShadowOver:shadowPackage withLight:light];

    // never loop the subviews here, and enumerate the subview may trigger loadView
}

- (BOOL)mth_shouldObjectAlive {
    BOOL shouldBeAlive = NO;

    if (self.window != nil) {
        shouldBeAlive = YES;
    }

    if (!shouldBeAlive && self.superview != nil && self.window != nil) {
        shouldBeAlive = YES;
    }

    if (!shouldBeAlive) {
        UIResponder *responder = self.nextResponder;
        while (responder) {
            if (responder.nextResponder == nil) {
                break;
            } else {
                responder = responder.nextResponder;
            }

            if ([responder isKindOfClass:[UIViewController class]]) {
                break;
            }
        }

        // if controller is active, view should be considered alive too.
        if ([responder isKindOfClass:[UIViewController class]]) {
            shouldBeAlive = YES;
        }
    }

    return shouldBeAlive;
}

@end

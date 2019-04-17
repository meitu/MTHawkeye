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
#import <sys/time.h>

#import <MTHawkeye/MTHawkeyeSignPosts.h>
#import <MTHawkeye/UIDevice+MTHLivingObjectSniffer.h>

#import "MTHLivingObjectShadow.h"
#import "MTHLivingObjectSniffService.h"
#import "MTH_RSSwizzle.h"
#import "NSObject+MTHLivingObjectSniffer.h"
#import "UIView+MTHLivingObjectSniffer.h"
#import "UIViewController+MTHLivingObjectSniffer.h"


static const void *const kMTHawkeyeViewControllerWillDealloc = &kMTHawkeyeViewControllerWillDealloc;


@interface UIViewController (MTMemoryDebuggerPrivate) <MTHLivingObjectShadowing>

@end


@implementation UIViewController (MTHLivingObjectSniffer)

+ (void)mthl_livingObjectSnifferSetup {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        static const void *key = &key;
        SEL selector = @selector(viewDidDisappear:);
        Class classToSwizzle = [UIViewController class];
        [MTH_RSSwizzle
            swizzleInstanceMethod:selector
                          inClass:classToSwizzle
                    newImpFactory:^id(MTH_RSSwizzleInfo *swizzleInfo) {
                        return ^void(__unsafe_unretained id self, BOOL animated) {
                            [self mthl_ViewDidDisappear:animated];

                            void (*originalIMP)(__unsafe_unretained id, SEL);
                            originalIMP = (__typeof(originalIMP))[swizzleInfo getOriginalImplementation];
                            originalIMP(self, selector);
                        };
                    }
                             mode:MTH_RSSwizzleModeOncePerClassAndSuperclasses
                              key:key];
    });
}

- (void)mthl_ViewDidDisappear:(BOOL)animated {
    if (![MTHLivingObjectSniffService shared].isRunning)
        return;

    if (![self isMovingFromParentViewController] && ![self isBeingDismissed])
        return;

    [self mthm_willDealloc];
}

- (void)mthm_willDealloc {
    MTHSignpostStart(510);

    MTHLivingObjectShadowTrigger *trigger = [[MTHLivingObjectShadowTrigger alloc] initWithType:MTHLivingObjectShadowTriggerTypeViewController];
    trigger.name = NSStringFromClass([self class]);
    NSMutableString *childVCs = [NSMutableString string];
    [self.childViewControllers enumerateObjectsUsingBlock:^(__kindof UIViewController *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        [childVCs appendString:NSStringFromClass([obj class])];
    }];
    trigger.nameExtra = childVCs.copy;
    trigger.startTime = CFAbsoluteTimeGetCurrent();

    MTHLivingObjectShadowPackage *package = [[MTHLivingObjectShadowPackage alloc] init];
    __weak __typeof(self) weakSelf = self;
    [self mth_castShadowOver:package withLight:weakSelf];

    trigger.endTime = CFAbsoluteTimeGetCurrent();

    NSTimeInterval delay = [MTHLivingObjectSniffService shared].delaySniffInSeconds;
    [[MTHLivingObjectSniffService shared].sniffer
        sniffWillReleasedLivingObjectShadowPackage:package
                                  expectReleasedIn:delay
                                       triggerInfo:trigger];

    MTHSignpostEnd(510);

#if _InternalMTHLivingObjectSnifferPerformanceTestEnabled
    printf("[hawkeye][profile] ViewController cast shadow: shadows %d, cost %.3fms \n", package.shadows.count, (trigger.endTime - trigger.startTime) * 1000);
#endif
}


// MARK: - MTHLivingObjectShadowing

- (BOOL)mth_castShadowOver:(MTHLivingObjectShadowPackage *)shadowPackage withLight:(nullable id)light {
    [self.childViewControllers enumerateObjectsUsingBlock:^(__kindof UIViewController *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        [obj mth_castShadowOver:shadowPackage withLight:light];
    }];

    [self.presentedViewController mth_castShadowOver:shadowPackage withLight:light];

    // self.view and traversal the subviews.
    if ([self isViewLoaded]) {
        [self.view mth_castShadowOver:shadowPackage withLight:light];
    }

    // traversal other properties
    return [super mth_castShadowOver:shadowPackage withLight:light];
}

- (MTHLivingObjectShadow *)mth_castShadowFromLight:(nullable id)light {
    return [super mth_castShadowFromLight:light];
}

- (BOOL)mth_shouldObjectAlive {
    if (![self isViewLoaded])
        return NO;

    BOOL shouldAlive = YES;
    BOOL visibleOnScreen = NO;

    UIView *v = self.view.window;

    if ([v isKindOfClass:[UIWindow class]]) {
        visibleOnScreen = YES;
    }

    BOOL beingHeld = NO;
    if (self.navigationController != nil || self.presentingViewController != nil || self.tabBarController != nil) {
        beingHeld = YES;
    }

    // not visible, not in view stack.
    if (visibleOnScreen == NO && beingHeld == NO) {
        shouldAlive = NO;
    }

    return shouldAlive;
}

@end

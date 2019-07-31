//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/5/31
// Created by: 潘名扬
//


#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import <MTHawkeye/MTH_RSSwizzle.h>
#import <MTHawkeye/MTHawkeyeHooking.h>
#import <MTHawkeye/MTHawkeyeUtility.h>

#import "MTHTimeIntervalRecorder.h"
#import "MTHUIViewControllerProfile.h"


static char const kAssociatedRemoverKey;

static NSString *const kUniqueFakeKeyPath = @"mth_useless_key_path";


#pragma mark - IMP of Key Method

/*
 while using VC Trace with ReactCocoa or Aspects, their implementation will change the _sel
 so we need to use hard code @selector to get the default while failed.
 */
static void mth_loadView(UIViewController *kvo_self, SEL _sel) {
    Class kvo_cls = object_getClass(kvo_self);
    Class origin_cls = class_getSuperclass(kvo_cls);
    SEL theSel = _sel;

    Method method = class_getInstanceMethod(origin_cls, theSel);
    if (!method) {
        theSel = @selector(loadView); // fallback to default Method.
        method = class_getInstanceMethod(origin_cls, theSel);
    }
    if (!method)
        return;

    IMP origin_imp = method_getImplementation(method);
    void (*func)(UIViewController *, SEL) = (void (*)(UIViewController *, SEL))origin_imp;

    [[MTHTimeIntervalRecorder shared] recordViewController:kvo_self processInStep:MTHViewControllerLifeCycleStepLoadViewEnter];
    func(kvo_self, theSel);
    [[MTHTimeIntervalRecorder shared] recordViewController:kvo_self processInStep:MTHViewControllerLifeCycleStepLoadViewExit];
}

static void mth_viewDidLoad(UIViewController *kvo_self, SEL _sel) {
    Class kvo_cls = object_getClass(kvo_self);
    Class origin_cls = class_getSuperclass(kvo_cls);
    SEL theSel = _sel;
    Method method = class_getInstanceMethod(origin_cls, theSel);
    if (!method) {
        theSel = @selector(viewDidLoad); // fallback to default Method.
        method = class_getInstanceMethod(origin_cls, theSel);
    }
    if (!method)
        return;

    IMP origin_imp = method_getImplementation(method);
    void (*func)(UIViewController *, SEL) = (void (*)(UIViewController *, SEL))origin_imp;

    [[MTHTimeIntervalRecorder shared] recordViewController:kvo_self processInStep:MTHViewControllerLifeCycleStepViewDidLoadEnter];
    func(kvo_self, theSel);
    [[MTHTimeIntervalRecorder shared] recordViewController:kvo_self processInStep:MTHViewControllerLifeCycleStepViewDidLoadExit];
}

static void mth_viewWillAppear(UIViewController *kvo_self, SEL _sel, BOOL animated) {
    Class kvo_cls = object_getClass(kvo_self);
    Class origin_cls = class_getSuperclass(kvo_cls);

    SEL theSel = _sel;
    Method method = class_getInstanceMethod(origin_cls, theSel);
    if (!method) {
        theSel = @selector(viewWillAppear:); // fallback to default Method.
        method = class_getInstanceMethod(origin_cls, theSel);
    }

    if (!method)
        return;

    IMP origin_imp = method_getImplementation(method);
    void (*func)(UIViewController *, SEL, BOOL) = (void (*)(UIViewController *, SEL, BOOL))origin_imp;

    [[MTHTimeIntervalRecorder shared] recordViewController:kvo_self processInStep:MTHViewControllerLifeCycleStepViewWillAppearEnter];
    func(kvo_self, theSel, animated);
    [[MTHTimeIntervalRecorder shared] recordViewController:kvo_self processInStep:MTHViewControllerLifeCycleStepViewWillAppearExit];
}

static void mth_viewDidAppear(UIViewController *kvo_self, SEL _sel, BOOL animated) {
    Class kvo_cls = object_getClass(kvo_self);
    Class origin_cls = class_getSuperclass(kvo_cls);
    SEL theSel = _sel;
    Method method = class_getInstanceMethod(origin_cls, theSel);
    if (!method) {
        theSel = @selector(viewDidAppear:); // fallback to default Method.
        method = class_getInstanceMethod(origin_cls, theSel);
    }
    if (!method) {
        return;
    }

    IMP origin_imp = method_getImplementation(method);
    void (*func)(UIViewController *, SEL, BOOL) = (void (*)(UIViewController *, SEL, BOOL))origin_imp;

    [[MTHTimeIntervalRecorder shared] recordViewController:kvo_self processInStep:MTHViewControllerLifeCycleStepViewDidAppearEnter];
    func(kvo_self, theSel, animated);
    [[MTHTimeIntervalRecorder shared] recordViewController:kvo_self processInStep:MTHViewControllerLifeCycleStepViewDidAppearExit];
}

#pragma mark -

@implementation MTHFakeKVOObserver

+ (instancetype)shared {
    static id sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

@end


#pragma mark -

@implementation MTHFakeKVORemover

- (void)dealloc {
    [_target removeObserver:[MTHFakeKVOObserver shared] forKeyPath:_keyPath];
    _target = nil;
}

@end


#pragma mark -

@implementation MTHUIViewControllerProfile

+ (void)startVCProfile {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if ([MTHawkeyeUtility underUnitTest])
            return;

        static const void *keyA = &keyA;
        static const void *keyB = &keyB;
        Class class = [UIViewController class];
        SEL initSEL1 = @selector(initWithNibName:bundle:);
        [MTH_RSSwizzle
            swizzleInstanceMethod:initSEL1
                          inClass:class
                    newImpFactory:^id(MTH_RSSwizzleInfo *swizzleInfo) {
                        return ^id(__unsafe_unretained id vc, NSString *nibNameOrNil, NSBundle *nibBundleOrNil) {
                            id (*originalIMP)(__unsafe_unretained id, SEL, NSString *, NSBundle *);
                            originalIMP = (__typeof(originalIMP))[swizzleInfo getOriginalImplementation];

                            [MTHUIViewControllerProfile mth_createAndHookKVOClassFor:vc];
                            originalIMP(vc, initSEL1, nibNameOrNil, nibBundleOrNil);
                            [[MTHTimeIntervalRecorder shared] recordViewController:vc processInStep:MTHViewControllerLifeCycleStepInitExit];
                            return vc;
                        };
                    }
                             mode:MTH_RSSwizzleModeOncePerClass
                              key:keyA];

        SEL initSEL2 = @selector(initWithCoder:);
        [MTH_RSSwizzle
            swizzleInstanceMethod:initSEL2
                          inClass:class
                    newImpFactory:^id(MTH_RSSwizzleInfo *swizzleInfo) {
                        return ^id(__unsafe_unretained id vc, NSCoder *coder) {
                            id (*originalIMP)(__unsafe_unretained id, SEL, NSCoder *);
                            originalIMP = (__typeof(originalIMP))[swizzleInfo getOriginalImplementation];

                            [MTHUIViewControllerProfile mth_createAndHookKVOClassFor:vc];
                            originalIMP(vc, initSEL2, coder);
                            [[MTHTimeIntervalRecorder shared] recordViewController:vc processInStep:MTHViewControllerLifeCycleStepInitExit];
                            return vc;
                        };
                    }
                             mode:MTH_RSSwizzleModeOncePerClass
                              key:keyB];
    });
}

+ (void)mth_createAndHookKVOClassFor:(UIViewController *)vc {
    // Setup KVO, which trigger runtime to create the KVO subclass of VC.
    [vc addObserver:[MTHFakeKVOObserver shared] forKeyPath:kUniqueFakeKeyPath options:NSKeyValueObservingOptionNew context:nil];

    // Setup remover of KVO, automatically remove KVO when VC dealloc.
    MTHFakeKVORemover *remover = [[MTHFakeKVORemover alloc] init];
    remover.target = vc;
    remover.keyPath = kUniqueFakeKeyPath;
    objc_setAssociatedObject(vc, &kAssociatedRemoverKey, remover, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // NSKVONotifying_ViewController
    Class kvoCls = object_getClass(vc);

    // Compare current Imp with our Imp. Make sure we didn't hooked before.
    IMP currentViewDidLoadImp = class_getMethodImplementation(kvoCls, @selector(viewDidLoad));
    if (currentViewDidLoadImp == (IMP)mth_viewDidLoad) {
        return;
    }

    // ViewController
    Class originCls = class_getSuperclass(kvoCls);

    Method loadViewMethod = class_getInstanceMethod(originCls, @selector(loadView));
    if (loadViewMethod) {
        const char *originLoadViewEncoding = method_getTypeEncoding(loadViewMethod);
        class_addMethod(kvoCls, @selector(loadView), (IMP)mth_loadView, originLoadViewEncoding);
    }

    Method viewDidloadMethod = class_getInstanceMethod(originCls, @selector(viewDidLoad));
    if (viewDidloadMethod) {
        const char *originViewDidLoadEncoding = method_getTypeEncoding(viewDidloadMethod);
        class_addMethod(kvoCls, @selector(viewDidLoad), (IMP)mth_viewDidLoad, originViewDidLoadEncoding);
    }

    Method willAppearMethod = class_getInstanceMethod(originCls, @selector(viewWillAppear:));
    if (willAppearMethod) {
        const char *originViewWillAppearEncoding = method_getTypeEncoding(willAppearMethod);
        class_addMethod(kvoCls, @selector(viewWillAppear:), (IMP)mth_viewWillAppear, originViewWillAppearEncoding);
    }

    Method didAppearMethod = class_getInstanceMethod(originCls, @selector(viewDidAppear:));
    if (didAppearMethod) {
        const char *originViewDidAppearEncoding = method_getTypeEncoding(didAppearMethod);
        class_addMethod(kvoCls, @selector(viewDidAppear:), (IMP)mth_viewDidAppear, originViewDidAppearEncoding);
    }
}

@end

//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/121/25
// Created by: EuanC
//


#import "MTHAppLaunchStepTracer.h"
#import "MTHTimeIntervalRecorder.h"

#import <MTHawkeye/MTHawkeyeHooking.h>
#import <sys/time.h>


#define kRecordRunloopActivityCount 50

@implementation MTHAppLaunchStepTracer

+ (void)traceSteps {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self traceObjcLoadFired];

        [self traceUIApplicationInit];
        [self traceAppDidLaunched];

        [self traceBackFrontSwitch];
    });
}

+ (void)traceObjcLoadFired {
    [[MTHTimeIntervalRecorder shared] recordAppLaunchStep:MTHAppLaunchStepObjcLoadStart];
}

+ (void)traceUIApplicationInit {
    // Hook init method of UIApplication
    SEL originalApplicationInitMethod = @selector(init);
    SEL swizzledApplicationInitMethod = [MTHawkeyeHooking swizzledSelectorForSelectorConstant:originalApplicationInitMethod];
    UIApplication * (^applicationInitBlock)(Class) = ^UIApplication *(Class class) {
        [[MTHTimeIntervalRecorder shared] recordAppLaunchStep:MTHAppLaunchStepApplicationInit];
        return ((UIApplication * (*)(Class, SEL)) objc_msgSend)(class, swizzledApplicationInitMethod);
    };
    [MTHawkeyeHooking replaceImplementationOfKnownSelector:originalApplicationInitMethod
                                                   onClass:UIApplication.class
                                                 withBlock:applicationInitBlock
                                          swizzledSelector:swizzledApplicationInitMethod];
}

+ (void)traceAppDidLaunched {
    // Hook appDidLaunch method
    Class appDelegateClass = NSClassFromString(@"AppDelegate");
    if (appDelegateClass) {
        SEL originalSelector = @selector(application:didFinishLaunchingWithOptions:);
        SEL swizzledSelector = [MTHawkeyeHooking swizzledSelectorForSelectorConstant:originalSelector];
        void (^appDidFinishLaunch)(id, UIApplication *, NSDictionary *) = ^void(id obj, UIApplication *application, NSDictionary *launchOptions) {
            // before app did launch

            [[MTHTimeIntervalRecorder shared] recordAppLaunchStep:MTHAppLaunchStepAppDidLaunchEnter];

            ((void (*)(id, SEL, UIApplication *, NSDictionary *))objc_msgSend)(obj, swizzledSelector, application, launchOptions);

            // after app did launch
            [[MTHTimeIntervalRecorder shared] recordAppLaunchStep:MTHAppLaunchStepAppDidLaunchExit];
        };
        [MTHawkeyeHooking replaceImplementationOfKnownSelector:originalSelector
                                                       onClass:appDelegateClass
                                                     withBlock:appDidFinishLaunch
                                              swizzledSelector:swizzledSelector];
    }
}

+ (void)traceRunloopActivity {
    static double *timeStamps;
    static unsigned long *activities;
    timeStamps = malloc(kRecordRunloopActivityCount * sizeof(double));
    activities = malloc(kRecordRunloopActivityCount * sizeof(unsigned long));
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopAllActivities, YES, -1, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        static unsigned long count = 0;

        if (count >= kRecordRunloopActivityCount)
            return;

        struct timeval now;
        gettimeofday(&now, NULL);
        timeStamps[count] = now.tv_sec + now.tv_usec * 1e-6;
        activities[count] = activity;

        if (DISPATCH_EXPECT(++count == kRecordRunloopActivityCount, NO)) {
            CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, kCFRunLoopDefaultMode);
            CFRunLoopObserverInvalidate(observer);
            CFRelease(observer);
            NSMutableArray<MTHRunloopActivityRecord *> *records = [NSMutableArray arrayWithCapacity:kRecordRunloopActivityCount];
            for (NSInteger i = 0; i < kRecordRunloopActivityCount; i++) {
                MTHRunloopActivityRecord *record = [[MTHRunloopActivityRecord alloc] init];
                record.timeStamp = timeStamps[i];
                record.activity = activities[i];
                [records addObject:record];
            }
            [[MTHTimeIntervalRecorder shared] recordMainRunLoopActivities:records];
            free(timeStamps);
            free(activities);
        }
    });
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopDefaultMode);
}

+ (void)traceBackFrontSwitch {
    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationWillEnterForegroundNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *_Nonnull note) {
                    [[MTHTimeIntervalRecorder shared] recordCustomEvent:@"App::WillEnterForeground"];
                }];

    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidEnterBackgroundNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *_Nonnull note) {
                    [[MTHTimeIntervalRecorder shared] recordCustomEvent:@"App::DidEnterBackground"];
                }];

    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidBecomeActiveNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *_Nonnull note) {
                    [[MTHTimeIntervalRecorder shared] recordCustomEvent:@"App::DidBecomeActive"];
                }];
}

@end

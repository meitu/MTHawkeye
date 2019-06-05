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

#import <MTHawkeye/MTH_RSSwizzle.h>
#import <MTHawkeye/MTHawkeyeHooking.h>
#import <sys/time.h>


#define kRecordRunloopActivityCount 50

@implementation MTHAppLaunchStepTracer

+ (void)traceSteps {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self traceObjcLoadFired];

        [self traceUIApplicationInit];

        [self traceBackFrontSwitch];
    });
}

+ (void)traceObjcLoadFired {
    [[MTHTimeIntervalRecorder shared] recordAppLaunchStep:MTHAppLaunchStepObjcLoadStart];
}

+ (void)traceUIApplicationInit {
    // Hook init method of UIApplication
    Class appCls = UIApplication.class;
    MTH_RSSwizzleInstanceMethod(appCls,
        @selector(init),
        MTH_RSSWReturnType(UIApplication *),
        MTH_RSSWArguments(),
        MTH_RSSWReplacement(
            [[MTHTimeIntervalRecorder shared] recordAppLaunchStep:MTHAppLaunchStepApplicationInit];
            return MTH_RSSWCallOriginal();),
        MTH_RSSwizzleModeAlways, NULL);


    MTH_RSSwizzleInstanceMethod(appCls,
        @selector(setDelegate:),
        MTH_RSSWReturnType(void),
        MTH_RSSWArguments(id<UIApplicationDelegate> delegate),
        MTH_RSSWReplacement(
            Class delCls = [delegate class];
            [MTHAppLaunchStepTracer traceAppDidLaunching:delCls];
            MTH_RSSWCallOriginal(delegate);),
        MTH_RSSwizzleModeAlways, NULL)
}

+ (void)traceAppDidLaunching:(Class)appDelegateClass {
    if (appDelegateClass) {
        SEL originalSelector = @selector(application:didFinishLaunchingWithOptions:);
        if (!originalSelector)
            return;

        static const void *didLaunchingSwizzlingkey = &didLaunchingSwizzlingkey;
        MTH_RSSwizzleInstanceMethod(appDelegateClass,
            originalSelector,
            MTH_RSSWReturnType(BOOL),
            MTH_RSSWArguments(UIApplication * app, NSDictionary * opt),
            MTH_RSSWReplacement(
                [[MTHTimeIntervalRecorder shared] recordAppLaunchStep:MTHAppLaunchStepAppDidLaunchEnter];

                BOOL res = MTH_RSSWCallOriginal(app, opt);

                [[MTHTimeIntervalRecorder shared] recordAppLaunchStep:MTHAppLaunchStepAppDidLaunchExit];

                return res;

                ),
            MTH_RSSwizzleModeOncePerClassAndSuperclasses, didLaunchingSwizzlingkey);
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
            [[MTHTimeIntervalRecorder shared] recordRunLoopActivities:records];
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

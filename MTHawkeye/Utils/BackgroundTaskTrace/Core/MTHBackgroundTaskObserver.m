//
//  MTHBackgroundTaskObserve.m
//  MTHawkeyeInjection
//
//  Created by Zed on 2019/5/22.
//

#import "MTHBackgroundTaskObserver.h"
#import "MTH_RSSwizzle.h"
#import "MTHawkeyeHooking.h"

static BOOL backgroundTaskObserverEnabled = NO;
static id<MTHBackgroundTaskObserverProcessDelegate> backgroundTaskObserverDelegate = nil;

@implementation MTHBackgroundTaskObserver

+ (void)setEnabled:(BOOL)enabled {
    backgroundTaskObserverEnabled = enabled;
    if (backgroundTaskObserverEnabled) {
        [self injectIntoUIAPPlicationBackgroundTask];
    }
}

+ (BOOL)isEnabled {
    return backgroundTaskObserverEnabled;
}

+ (void)setMTHBackgroundTaskObserverProcessDelegate:(_Nullable id<MTHBackgroundTaskObserverProcessDelegate>)delegate {
    backgroundTaskObserverDelegate = delegate;
}


typedef void (^voidBlock)(void);

+ (void)injectIntoUIAPPlicationBackgroundTask {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class classToSwizzle = [UIApplication class];
        SEL selector1 = @selector(beginBackgroundTaskWithExpirationHandler:);
        SEL swizzledSelector1 = [MTHawkeyeHooking swizzledSelectorForSelector:selector1];
        UIBackgroundTaskIdentifier (^creatorSwizzleBlock1)(Class, voidBlock) = ^UIBackgroundTaskIdentifier(Class slf, voidBlock expirationHandler) {
            UIBackgroundTaskIdentifier identifier = UIBackgroundTaskInvalid;
            identifier = ((UIBackgroundTaskIdentifier(*)(id, SEL, id))objc_msgSend)(slf, swizzledSelector1, expirationHandler);
            if ([MTHBackgroundTaskObserver isEnabled]) {
                // 记录begin, 当前堆栈和当前ID
                if (backgroundTaskObserverDelegate && [backgroundTaskObserverDelegate respondsToSelector:@selector(processBeginBackgroundTask:taskName:)]) {
                    [backgroundTaskObserverDelegate processBeginBackgroundTask:identifier taskName:@""];
                }
            }
            return identifier;
        };
        [MTHawkeyeHooking replaceImplementationOfKnownSelector:selector1
                                                       onClass:classToSwizzle
                                                     withBlock:creatorSwizzleBlock1
                                              swizzledSelector:swizzledSelector1];

        SEL selector2 = @selector(beginBackgroundTaskWithName:expirationHandler:);
        SEL swizzledSelector2 = [MTHawkeyeHooking swizzledSelectorForSelector:selector2];
        UIBackgroundTaskIdentifier (^creatorSwizzleBlock2)(Class, NSString *, voidBlock) = ^UIBackgroundTaskIdentifier(Class slf, NSString *string, voidBlock expirationHandler) {
            UIBackgroundTaskIdentifier identifier = UIBackgroundTaskInvalid;
            identifier = ((UIBackgroundTaskIdentifier(*)(id, SEL, id, id))objc_msgSend)(slf, swizzledSelector2, string, expirationHandler);
            // 记录begin, 当前堆栈和当前ID
            if (backgroundTaskObserverDelegate && [backgroundTaskObserverDelegate respondsToSelector:@selector(processBeginBackgroundTask:taskName:)]) {
                [backgroundTaskObserverDelegate processBeginBackgroundTask:identifier taskName:string];
            }
            return identifier;
        };
        [MTHawkeyeHooking replaceImplementationOfKnownSelector:selector2
                                                       onClass:classToSwizzle
                                                     withBlock:creatorSwizzleBlock2
                                              swizzledSelector:swizzledSelector2];

        SEL selector3 = @selector(endBackgroundTask:);
        SEL swizzledSelector3 = [MTHawkeyeHooking swizzledSelectorForSelector:selector3];
        void (^creatorSwizzleBlock3)(Class, NSUInteger) = ^void(Class slf, NSUInteger identifier) {
            ((UIBackgroundTaskIdentifier(*)(id, SEL, NSUInteger))objc_msgSend)(slf, swizzledSelector3, identifier);

            // 记录end
            if (backgroundTaskObserverDelegate && [backgroundTaskObserverDelegate respondsToSelector:@selector(processEndBackgroundTask:)]) {
                [backgroundTaskObserverDelegate processEndBackgroundTask:identifier];
            }
        };
        [MTHawkeyeHooking replaceImplementationOfKnownSelector:selector3
                                                       onClass:classToSwizzle
                                                     withBlock:creatorSwizzleBlock3
                                              swizzledSelector:swizzledSelector3];
    });
}

@end

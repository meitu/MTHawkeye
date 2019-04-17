//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/8
// Created by: EuanC
//


#import "MTHTimeRecord.h"


@implementation MTHViewControllerAppearRecord

- (NSTimeInterval)appearCostInMS {
    if (self.viewDidAppearExitTime == 0.f) {
        return 0.f;
    }

    if (self.loadViewEnterTime) {
        return (self.viewDidAppearExitTime - self.loadViewEnterTime) * 1000.f;
    } else if (self.viewDidLoadEnterTime) {
        return (self.viewDidAppearExitTime - self.viewDidLoadEnterTime) * 1000.f;
    } else if (self.viewWillAppearEnterTime) {
        return (self.viewDidAppearExitTime - self.viewWillAppearEnterTime) * 1000.f;
    } else {
        return 0.f;
    }
}

- (NSString *)description {
    if (self.viewDidAppearExitTime == 0.f) {
        return self.className;
    }

    if (self.loadViewEnterTime) {
        return [NSString stringWithFormat:@"%@, %@ ⇤%.2fms⇥ Appeared", self.className, @"Load", [self appearCostInMS]];
    } else if (self.viewDidLoadEnterTime) {
        return [NSString stringWithFormat:@"%@, %@ ⇤%.2fms⇥ Appeared", self.className, @"DidLoad", [self appearCostInMS]];
    } else if (self.viewWillAppearEnterTime) {
        return [NSString stringWithFormat:@"%@, %@ ⇤%.2fms⇥ Appeared", self.className, @"WillAppear", [self appearCostInMS]];
    }
    return self.className;
}


- (NSTimeInterval)timeStampOfStep:(MTHViewControllerLifeCycleStep)step {
    switch (step) {
        case MTHViewControllerLifeCycleStepUnknown:
            return 0.f;
        case MTHViewControllerLifeCycleStepInitExit:
            return self.initExitTime;
        case MTHViewControllerLifeCycleStepLoadViewEnter:
            return self.loadViewEnterTime;
        case MTHViewControllerLifeCycleStepLoadViewExit:
            return self.loadViewExitTime;
        case MTHViewControllerLifeCycleStepViewDidLoadEnter:
            return self.viewDidLoadEnterTime;
        case MTHViewControllerLifeCycleStepViewDidLoadExit:
            return self.viewDidLoadExitTime;
        case MTHViewControllerLifeCycleStepViewWillAppearEnter:
            return self.viewWillAppearEnterTime;
        case MTHViewControllerLifeCycleStepViewWillAppearExit:
            return self.viewWillAppearExitTime;
        case MTHViewControllerLifeCycleStepViewDidAppearEnter:
            return self.viewDidAppearEnterTime;
        case MTHViewControllerLifeCycleStepViewDidAppearExit:
            return self.viewDidAppearExitTime;
        default:
            return 0.f;
    }
}

+ (NSString *)displayNameOfStep:(MTHViewControllerLifeCycleStep)step {
    switch (step) {
        case MTHViewControllerLifeCycleStepUnknown:
            return nil;
        case MTHViewControllerLifeCycleStepInitExit:
            return @"↥ VC init";
        case MTHViewControllerLifeCycleStepLoadViewEnter:
            return @"↧ loadView";
        case MTHViewControllerLifeCycleStepLoadViewExit:
            return @"↥ loadView";
        case MTHViewControllerLifeCycleStepViewDidLoadEnter:
            return @"↧ viewDidLoad";
        case MTHViewControllerLifeCycleStepViewDidLoadExit:
            return @"↥ viewDidLoad";
        case MTHViewControllerLifeCycleStepViewWillAppearEnter:
            return @"↧ viewWillAppear:";
        case MTHViewControllerLifeCycleStepViewWillAppearExit:
            return @"↥ viewWillAppear:";
        case MTHViewControllerLifeCycleStepViewDidAppearEnter:
            return @"↧ viewDidAppear:";
        case MTHViewControllerLifeCycleStepViewDidAppearExit:
            return @"↥ viewDidAppear:";
        default:
            return nil;
    }
}

@end


#pragma mark -

@implementation MTHRunloopActivityRecord
@end

#pragma mark -

@implementation MTHTimeIntervalCustomEventRecord

- (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[NSDateFormatter alloc] init];
        _sharedInstance.dateFormat = @"mm:ss.SSS";
        _sharedInstance.timeZone = [NSTimeZone localTimeZone];
    });

    return _sharedInstance;
}

- (NSString *)description {
    NSMutableString *desc = [NSMutableString string];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:self.timeStamp];
    [desc appendFormat:@"%13s | ", [[[self dateFormatter] stringFromDate:date] UTF8String]];
    [desc appendString:self.event];
    if (self.extra.length > 0) {
        [desc appendString:@"\n"];
        [desc appendFormat:@"%15s | %@", "", self.extra];
    }
    return [desc copy];
}

@end

#pragma mark -

@implementation MTHAppLaunchRecord

+ (NSString *)displayNameOfStep:(MTHAppLaunchStep)step {
    switch (step) {
        case MTHAppLaunchStepAppLaunch:
            return @"🔌 App Launched";
        case MTHAppLaunchStepObjcLoadStart:
            return @"🕓 First ObjC +load enter";
        case MTHAppLaunchStepObjcLoadEnd:
            return @"🕔 Last ObjC +load exit";
        case MTHAppLaunchStepStaticInitializerStart:
            return @"🕕 Static Initializer enter";
        case MTHAppLaunchStepStaticInitializerEnd:
            return @"🕖 Static Initializer exit";
        case MTHAppLaunchStepApplicationInit:
            return @"🕘 UIApplication init";
        case MTHAppLaunchStepAppDidLaunchEnter:
            return @"🕙 AppDidFinishLaunch enter";
        case MTHAppLaunchStepAppDidLaunchExit:
            return @"🕚 AppDidFinishLaunch exit";
        case MTHAppLaunchStepUnknown:
            return nil;
        default:
            return nil;
    }
}

- (NSTimeInterval)timeStampOfStep:(MTHAppLaunchStep)step {
    NSTimeInterval timeStamp = 0.f;
    switch (step) {
        case MTHAppLaunchStepAppLaunch:
            timeStamp = self.appLaunchTime;
            break;
        case MTHAppLaunchStepObjcLoadStart:
            timeStamp = self.firstObjcLoadStartTime;
            break;
        case MTHAppLaunchStepObjcLoadEnd:
            timeStamp = self.lastObjcLoadEndTime;
            break;
        case MTHAppLaunchStepStaticInitializerStart:
            timeStamp = self.staticInitializerStartTime;
            break;
        case MTHAppLaunchStepStaticInitializerEnd:
            timeStamp = self.staticInitializerEndTime;
            break;
        case MTHAppLaunchStepApplicationInit:
            timeStamp = self.applicationInitTime;
            break;
        case MTHAppLaunchStepAppDidLaunchEnter:
            timeStamp = self.appDidLaunchEnterTime;
            break;
        case MTHAppLaunchStepAppDidLaunchExit:
            timeStamp = self.appDidLaunchExitTime;
            break;
        case MTHAppLaunchStepUnknown:
            break;
    }
    return timeStamp;
}

@end

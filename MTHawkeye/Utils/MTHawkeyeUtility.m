//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 4/18/18
// Created by: EuanC
//


#import "MTHawkeyeUtility.h"
#import <ImageIO/ImageIO.h>
#import <objc/runtime.h>
#import <sys/sysctl.h>
#import <sys/time.h>
#import <zlib.h>

static NSInteger underUnitTest = -1;

static NSString *gMTHawkeyeRootDirectoryName = @"/com.meitu.hawkeye";

#if MTHawkeye_Store_Under_LibraryCache
MTHawkeyeStoreDirectoryOption gMTHawkeyeStoreDirectoryRoot = MTHawkeyeStoreDirectoryOptionLibraryCaches;
#elif MTHawkeye_Store_Under_Tmp
MTHawkeyeStoreDirectoryOption gMTHawkeyeStoreDirectoryRoot = MTHawkeyeStoreDirectoryOptionTmp;
#else
MTHawkeyeStoreDirectoryOption gMTHawkeyeStoreDirectoryRoot = MTHawkeyeStoreDirectoryOptionDocument;
#endif

@implementation MTHawkeyeUtility

+ (BOOL)underUnitTest {
    if (underUnitTest == -1) {
        if ([NSProcessInfo processInfo].environment[@"XCInjectBundleInto"] != nil)
            underUnitTest = 1;
        else
            underUnitTest = 0;
    }
    return underUnitTest == 1 ? YES : NO;
}

+ (double)currentTime {
    struct timeval t0;
    gettimeofday(&t0, NULL);
    return t0.tv_sec + t0.tv_usec * 1e-6;
}

+ (NSTimeInterval)appLaunchedTime {
    static NSTimeInterval appLaunchedTime;
    if (appLaunchedTime == 0.f) {
        struct kinfo_proc procInfo;
        size_t structSize = sizeof(procInfo);
        int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};

        if (sysctl(mib, sizeof(mib) / sizeof(*mib), &procInfo, &structSize, NULL, 0) != 0) {
            NSLog(@"sysctrl failed");
            appLaunchedTime = [[NSDate date] timeIntervalSince1970];
        } else {
            struct timeval t = procInfo.kp_proc.p_un.__p_starttime;
            appLaunchedTime = t.tv_sec + t.tv_usec * 1e-6;
        }
    }
    return appLaunchedTime;
}

+ (NSString *)hawkeyeStoreDirectory {
    if (gMTHawkeyeStoreDirectoryRoot == MTHawkeyeStoreDirectoryOptionDocument)
        return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:gMTHawkeyeRootDirectoryName];
    else if (gMTHawkeyeStoreDirectoryRoot == MTHawkeyeStoreDirectoryOptionLibraryCaches)
        return [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:gMTHawkeyeRootDirectoryName];
    else if (gMTHawkeyeStoreDirectoryRoot == MTHawkeyeStoreDirectoryOptionTmp)
        return [NSTemporaryDirectory() stringByAppendingPathComponent:gMTHawkeyeRootDirectoryName];
    else
        return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:gMTHawkeyeRootDirectoryName];
}

+ (NSString *)currentStoreDirectoryNameFormat {
    return @"yyyy-MM-dd_HH-mm-ss+SSS";
}

+ (NSString *)currentStorePath {
    static dispatch_once_t onceToken;
    static NSString *storeDirectory;
    dispatch_once(&onceToken, ^{
        NSString *hawkeyePath = [MTHawkeyeUtility hawkeyeStoreDirectory];
        NSString *formattedDateString = [self currentStorePathLastComponent];
        storeDirectory = [hawkeyePath stringByAppendingPathComponent:formattedDateString];
    });
    return storeDirectory;
}

+ (NSString *)currentStorePathLastComponent {
    NSTimeInterval appLaunchedTime = [MTHawkeyeUtility appLaunchedTime];
    NSDate *launchedDate = [NSDate dateWithTimeIntervalSince1970:appLaunchedTime];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:[self currentStoreDirectoryNameFormat]];
    [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
    NSString *formattedDateString = [dateFormatter stringFromDate:launchedDate];
    return formattedDateString;
}

+ (NSString *)previousSessionStorePath {
    static dispatch_once_t onceToken;
    static NSString *preStoreDirectory = nil;
    dispatch_once(&onceToken, ^{
        NSString *hawkeyePath = [MTHawkeyeUtility hawkeyeStoreDirectory];
        NSArray<NSString *> *logDirectories = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:hawkeyePath error:NULL];

        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:[MTHawkeyeUtility currentStoreDirectoryNameFormat]];
        [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];

        NSIndexSet *cachesIndexSet = [logDirectories
            indexesOfObjectsWithOptions:0
                            passingTest:^BOOL(NSString *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                                NSDate *createDate = [dateFormatter dateFromString:obj];
                                return createDate ? YES : NO;
                            }];
        logDirectories = [logDirectories objectsAtIndexes:cachesIndexSet];
        logDirectories = [logDirectories sortedArrayUsingComparator:^NSComparisonResult(NSString *_Nonnull obj1, NSString *_Nonnull obj2) {
            return [obj2 compare:obj1];
        }];

        NSString *currentSessionDirName = [self currentStorePathLastComponent];
        // in case current session directory not creat yet.
        if ([logDirectories.firstObject isEqualToString:currentSessionDirName]) {
            if (logDirectories.count >= 2) {
                preStoreDirectory = [hawkeyePath stringByAppendingPathComponent:logDirectories[1]];
            }
        } else {
            preStoreDirectory = [hawkeyePath stringByAppendingPathComponent:[logDirectories firstObject]];
        }
    });
    return preStoreDirectory;
}

@end

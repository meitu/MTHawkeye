//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/20
// Created by: EuanC
//


#import "MTHANRHawkeyeAdaptor.h"
#import "MTHANRTrace.h"
#import "MTHANRTracingBuffer.h"
#import "MTHawkeyeUserDefaults+ANRMonitor.h"

#import <MTHawkeye/MTHANRRecord.h>
#import <MTHawkeye/MTHawkeyeDyldImagesStorage.h>
#import <MTHawkeye/MTHawkeyeLogMacros.h>
#import <MTHawkeye/MTHawkeyeStorage.h>
#import <MTHawkeye/MTHawkeyeUtility.h>


@interface MTHANRHawkeyeAdaptor () <MTHANRTraceDelegate>

@end

@implementation MTHANRHawkeyeAdaptor

- (void)dealloc {
    [self unobserveANRSettingChange];
}

- (instancetype)init {
    if ((self = [super init])) {
        [self observeANRSettingChange];
    }
    return self;
}

- (void)observeANRSettingChange {
    __weak __typeof(self) weakSelf = self;
    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(anrTraceOn))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                if ([newValue boolValue])
                    [weakSelf startANRTrace];
                else
                    [weakSelf stopANRTrace];
            }];

    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(anrThresholdInSeconds))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                if (fabsf([oldValue floatValue] - [newValue floatValue]) > FLT_EPSILON)
                    [MTHANRTrace shared].thresholdInSeconds = [newValue floatValue];
            }];

    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(anrDetectInterval))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                if (fabsf([oldValue floatValue] - [newValue floatValue]) > FLT_EPSILON)
                    [MTHANRTrace shared].detectInterval = [newValue floatValue];
            }];
}

- (void)unobserveANRSettingChange {
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(anrTraceOn))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(anrThresholdInSeconds))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(anrDetectInterval))];
}

// MARK: - MTHawkeyePlugin
+ (NSString *)pluginID {
    return @"anr-tracer";
}

- (void)hawkeyeClientDidStart {
    if (![MTHawkeyeUserDefaults shared].anrTraceOn)
        return;

    [self startANRTrace];
}

- (void)hawkeyeClientDidStop {
    [self stopANRTrace];
}

- (void)startANRTrace {
    if ([[MTHANRTrace shared] isRunning])
        return;

    // enable anr trace buffer, needed for tracing hard stall(stall then killed by watchdog or user)
    if (![MTHANRTracingBuffer isTracingBufferRunning]) {
        NSString *path = [[MTHawkeyeUtility hawkeyeStoreDirectory] stringByAppendingPathComponent:@"anr_tracing_buffer"];
        [MTHANRTracingBuffer enableTracingBufferOn:path];
    }

    [MTHANRTrace shared].thresholdInSeconds = [MTHawkeyeUserDefaults shared].anrThresholdInSeconds;
    [MTHANRTrace shared].shouldCaptureBackTrace = YES;

    [[MTHANRTrace shared] addDelegate:self];
    [[MTHANRTrace shared] start];

    MTHLogInfo(@"ANR trace start");

    // needed for remote symbolics
    [MTHawkeyeDyldImagesStorage asyncCacheDyldImagesInfoIfNeeded];
}

- (void)stopANRTrace {
    if (![[MTHANRTrace shared] isRunning])
        return;

    if ([MTHANRTracingBuffer isTracingBufferRunning]) {
        [MTHANRTracingBuffer disableTracingBuffer];
    }

    [[MTHANRTrace shared] removeDelegate:self];
    [[MTHANRTrace shared] stop];
    MTHLogInfo(@"ANR trace stop");
}

// MARK: - MTHANRTraceDelegate
- (void)mth_anrMonitor:(MTHANRTrace *)anrMonitor didDetectANR:(MTHANRRecord *)anrRecord {
    [self storeANRRecord:anrRecord];
}

// MARK: - storage
- (void)storeANRRecord:(MTHANRRecord *)anrRecord {
    NSString *curTime = [NSString stringWithFormat:@"%@", @([MTHawkeyeUtility currentTime])];

    NSMutableArray<NSDictionary *> *stacks = [NSMutableArray array];
    for (MTHANRRecordRaw *rawRecord in anrRecord.rawRecords) {
        NSMutableString *stackInStr = [[NSMutableString alloc] init];
        for (int i = 0; i < rawRecord->stackframesSize; ++i) {
            [stackInStr appendFormat:@"%p,", (void *)rawRecord->stackframes[i]];
        }
        if (stackInStr.length > 1) {
            [stackInStr deleteCharactersInRange:NSMakeRange(stackInStr.length - 1, 1)];
        }

        NSDictionary *dict = @{
            @"time" : @(rawRecord.time),
            @"stackframes" : stackInStr.copy,
            @"titleframe" : [NSString stringWithFormat:@"%p", (void *)rawRecord->titleFrame]
        };
        [stacks addObject:dict];
    }

    NSDictionary *dict = @{
        @"duration" : [NSString stringWithFormat:@"%@", @(anrRecord.duration * 1000)],
        @"biases" : [NSString stringWithFormat:@"%@", @(anrRecord.biases * 1000)],
        @"stacks" : stacks
    };
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict.copy options:0 error:&error];
    if (!error) {
        NSString *value = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [[MTHawkeyeStorage shared] asyncStoreValue:value withKey:curTime inCollection:@"anr"];
    } else {
        MTHLogWarn(@"[storage] store anr record failed: %@", error.localizedDescription);
    }
}

+ (NSArray<MTHANRRecord *> *)readANRRecords {
    NSArray *times;
    NSArray *anrRecordsInJSON;
    [[MTHawkeyeStorage shared] readKeyValuesInCollection:@"anr" keys:&times values:&anrRecordsInJSON];

    NSMutableArray *anrRecords = @[].mutableCopy;
    for (NSString *recordInJSON in anrRecordsInJSON) {
        NSData *data = [recordInJSON dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (!error) {
            MTHANRRecord *record = [[MTHANRRecord alloc] init];
            NSMutableArray *rawReocrds = [NSMutableArray array];
            NSArray<NSDictionary *> *stacks = dict[@"stacks"];
            for (NSDictionary *stack in stacks) {
                MTHANRRecordRaw *rawRecord = [[MTHANRRecordRaw alloc] init];
                NSArray *stackInStr = [stack[@"stackframes"] componentsSeparatedByString:@","];
                rawRecord->stackframesSize = stackInStr.count;
                rawRecord->stackframes = malloc(sizeof(uintptr_t) * rawRecord->stackframesSize);
                for (int i = 0; i < stackInStr.count; ++i) {
                    NSString *frameInStr = stackInStr[i];
                    if (frameInStr.length < 3)
                        continue;

                    unsigned long long frame = 0;
                    NSScanner *scanner = [NSScanner scannerWithString:frameInStr];
                    [scanner setScanLocation:2];
                    [scanner scanHexLongLong:&frame];
                    rawRecord->stackframes[i] = (uintptr_t)frame;
                }

                unsigned long long titleframe = 0;
                NSString *titleFrame = stack[@"titleframe"];
                if (titleFrame.length > 0) {
                    NSScanner *scanner = [NSScanner scannerWithString:titleFrame];
                    [scanner setScanLocation:2];
                    [scanner scanHexLongLong:&titleframe];
                    rawRecord->titleFrame = (uintptr_t)titleframe;
                }

                rawRecord.time = [stack[@"time"] doubleValue];
                [rawReocrds addObject:rawRecord];
            }

            record.duration = [dict[@"duration"] doubleValue];
            record.biases = [dict[@"biases"] doubleValue];
            record.rawRecords = rawReocrds;
            [anrRecords addObject:record];
        } else {
            MTHLogWarn(@"[storage] read anr record failed, %@", error);
        }
    }

    return anrRecords.copy;
}

@end

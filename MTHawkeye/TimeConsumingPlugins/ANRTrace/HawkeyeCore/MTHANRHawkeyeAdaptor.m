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
                    [MTHANRTrace shared].detectIntervalInSeconds = [newValue floatValue];
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
    if (![MTHANRTracingBufferRunner isTracingBufferRunning]) {
        NSString *storagePath = [MTHawkeyeUtility currentStorePath];
        if (![[NSFileManager defaultManager] fileExistsAtPath:storagePath]) {
            [MTHawkeyeStorage shared];
        }
        NSString *path = [storagePath stringByAppendingPathComponent:@"anr_tracing_buffer"];
        [MTHANRTracingBufferRunner enableTracingBufferAtPath:path];
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

    if ([MTHANRTracingBufferRunner isTracingBufferRunning]) {
        [MTHANRTracingBufferRunner disableTracingBuffer];
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

    // if total strings > 16kB should seperate it
    NSMutableArray<NSDictionary *> *safeLengthStacks = [NSMutableArray array];
    NSMutableArray<NSMutableArray<NSDictionary *> *> *safeLengthStacksArrary = [NSMutableArray array];
    NSMutableArray<NSNumber *> *stacksDurationArrary = [NSMutableArray array];
    NSUInteger estimateLength = 0, currentDuration = 0;

    for (NSUInteger index = 0; index < anrRecord.stallingSnapshots.count; index++) {
        MTHANRMainThreadStallingSnapshot *rawRecord = anrRecord.stallingSnapshots[index];
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
            @"titleframe" : [NSString stringWithFormat:@"%p", (void *)rawRecord->titleFrame],
            @"capturedCount" : @(rawRecord.capturedCount),
            @"threadCount" : @(rawRecord.totalThreadCount),
        };
        estimateLength += 150 + stackInStr.length; // other string estimate length in 150 Bytes

        if (kMTHawkeyeLogStoreMaxLength <= estimateLength) {
            NSTimeInterval startFrom = ((NSNumber *)[[safeLengthStacks firstObject] objectForKey:@"time"]).doubleValue;
            NSTimeInterval duration = 0;
            if (index + 1 < anrRecord.stallingSnapshots.count) {
                duration = anrRecord.stallingSnapshots[index + 1].time - startFrom;
            } else {
                duration = anrRecord.durationInSeconds - currentDuration;
            }
            [stacksDurationArrary addObject:@(duration)];
            [safeLengthStacksArrary addObject:safeLengthStacks];

            currentDuration += duration;
            estimateLength = 0;
            safeLengthStacks = [NSMutableArray array];
        }

        [safeLengthStacks addObject:dict];
    }

    if ([safeLengthStacks count]) {
        [stacksDurationArrary addObject:@(anrRecord.durationInSeconds - currentDuration)];
        [safeLengthStacksArrary addObject:safeLengthStacks];
    }

    NSTimeInterval durationInSeconds = anrRecord.durationInSeconds;
    NSTimeInterval startFromInSeconds = anrRecord.startFrom;
    for (NSUInteger index = 0; index < safeLengthStacksArrary.count; index++) {
        NSMutableArray<NSDictionary *> *stacks = safeLengthStacksArrary[index];
        if (safeLengthStacksArrary.count > 1) {
            startFromInSeconds = ((NSNumber *)[[stacks firstObject] objectForKey:@"time"]).doubleValue;
            durationInSeconds = [stacksDurationArrary objectAtIndex:index].doubleValue;
        }

        NSDictionary *dict = @{
            @"duration" : @(durationInSeconds * 1000),
            @"startFrom" : @(startFromInSeconds),
            @"inBackground" : @(anrRecord.isInBackground),
            @"stacks" : stacks
        };
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict.copy options:0 error:&error];
        if (!error) {
            NSString *value = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            NSString *anrRecordKey = [NSString stringWithFormat:@"%@_%lu", curTime, (unsigned long)index];
            [[MTHawkeyeStorage shared] asyncStoreValue:value withKey:anrRecordKey inCollection:@"anr"];
        } else {
            MTHLogWarn(@"[storage] store anr record failed: %@", error.localizedDescription);
        }
    }
}

+ (NSArray<MTHANRRecord *> *)readANRRecords {
    NSArray *keys;
    NSArray *anrRecordsInJSON;
    [[MTHawkeyeStorage shared] readKeyValuesInCollection:@"anr" keys:&keys values:&anrRecordsInJSON];

    NSMutableArray *anrRecords = @[].mutableCopy;
    NSMutableArray *anrRecordKeys = [NSMutableArray arrayWithArray:keys];
    for (NSUInteger index = 0; index < anrRecordsInJSON.count; index++) {
        NSString *recordInJSON = anrRecordsInJSON[index];
        NSData *data = [recordInJSON dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (!error) {
            MTHANRRecord *record = [[MTHANRRecord alloc] init];
            NSMutableArray *rawReocrds = [NSMutableArray array];
            NSArray<NSDictionary *> *stacks = dict[@"stacks"];
            for (NSDictionary *stack in stacks) {
                MTHANRMainThreadStallingSnapshot *rawRecord = [[MTHANRMainThreadStallingSnapshot alloc] init];
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
                rawRecord.capturedCount = [stack[@"capturedCount"] integerValue];
                rawRecord.totalThreadCount = [stack[@"threadCount"] integerValue];
                [rawReocrds addObject:rawRecord];
            }

            record.durationInSeconds = [dict[@"duration"] doubleValue];
            record.startFrom = [dict[@"startFrom"] doubleValue];
            record.isInBackground = [dict[@"inBackground"] boolValue];
            record.stallingSnapshots = rawReocrds;
            [anrRecords addObject:record];
        } else {
            [anrRecordKeys removeObjectAtIndex:index];
            MTHLogWarn(@"[storage] read anr record failed, %@", error);
        }
    }

    NSArray<MTHANRRecord *> *records = anrRecords.copy;
    NSMutableDictionary<NSString *, NSMutableArray *> *dic = [NSMutableDictionary dictionary];
    for (NSUInteger index = 0; index < anrRecordKeys.count; index++) {
        NSString *anrKey = anrRecordKeys[index];
        NSString *timeKey = [[anrKey componentsSeparatedByString:@"_"] firstObject];
        NSMutableArray *sametimeRecords = [dic objectForKey:timeKey];
        if (!sametimeRecords) {
            sametimeRecords = [NSMutableArray array];
            [dic setObject:sametimeRecords forKey:timeKey];
        }
        [sametimeRecords addObject:records[index]];
    }

    NSMutableArray<MTHANRRecord *> *resultRecords = [NSMutableArray array];
    NSArray<NSMutableArray *> *categoryRecords = [dic allValues];
    for (NSMutableArray<MTHANRRecord *> *sametimeRecords in categoryRecords) {
        if (sametimeRecords.count == 1) {
            [resultRecords addObject:[sametimeRecords firstObject]];
        } else {
            MTHANRRecord *record = [[MTHANRRecord alloc] init];
            NSMutableArray<MTHANRMainThreadStallingSnapshot *> *rawRecords = [NSMutableArray array];
            for (MTHANRRecord *sametimeRecord in sametimeRecords) {
                [rawRecords addObjectsFromArray:sametimeRecord.stallingSnapshots];
                record.durationInSeconds += sametimeRecord.durationInSeconds;
            }
            [rawRecords sortUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
                MTHANRMainThreadStallingSnapshot *rawRecord1 = obj1;
                MTHANRMainThreadStallingSnapshot *rawRecord2 = obj2;
                if (rawRecord1.time < rawRecord2.time) {
                    return NSOrderedAscending;
                } else if (rawRecord1.time > rawRecord2.time) {
                    return NSOrderedDescending;
                }
                return NSOrderedSame;
            }];
            NSNumber *minStartFrom = [sametimeRecords valueForKeyPath:@"@min.startFrom"];
            record.startFrom = minStartFrom.doubleValue;
            record.isInBackground = [[sametimeRecords firstObject] isInBackground];
            record.stallingSnapshots = rawRecords;
            [resultRecords addObject:record];
        }
    }

    return resultRecords.copy;
}

@end

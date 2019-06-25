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


#import "MTHCPUTraceHawkeyeAdaptor.h"
#import "MTHCPUTrace.h"
#import "MTHCPUTraceHighLoadRecord.h"
#import "MTHawkeyeUserDefaults+CPUTrace.h"

#import <MTHawkeye/MTHawkeyeDyldImagesStorage.h>
#import <MTHawkeye/MTHawkeyeLogMacros.h>
#import <MTHawkeye/MTHawkeyeStorage.h>
#import <MTHawkeye/MTHawkeyeUserDefaults.h>


@interface MTHCPUTraceHawkeyeAdaptor () <MTHCPUTracingDelegate> {
    MTH_CPUTraceStackFramesNode *_currentSampleStackFrame;
}

@property (nonatomic, strong) MTHCPUTraceHighLoadRecord *currentRecord;

@end

@implementation MTHCPUTraceHawkeyeAdaptor

- (void)dealloc {
    [self unobserverCPUTraceHawkeyeSetting];
    [self unObserveAppEnterBackground];
}

- (instancetype)init {
    if ((self = [super init])) {
        [self observerCPUTraceHawkeyeSetting];
        [self unObserveAppEnterBackground];
    }
    return self;
}

+ (NSString *)pluginID {
    return @"cpu-tracer";
}

- (void)hawkeyeClientDidStart {
    if (![MTHawkeyeUserDefaults shared].cpuTraceOn)
        return;

    MTHLogInfo(@"cpu trace start");
    MTHCPUTrace *tracer = [MTHCPUTrace shareInstance];
    MTHawkeyeUserDefaults *userDefault = [MTHawkeyeUserDefaults shared];
    tracer.highLoadThreshold = userDefault.cpuTraceHighLoadThreshold;
    tracer.highLoadLastingLimit = userDefault.cpuTraceHighLoadLastingLimit;
    tracer.checkIntervalIdle = userDefault.cpuTraceCheckIntervalIdle;
    tracer.checkIntervalBusy = userDefault.cpuTraceCheckIntervalBusy;
    tracer.stackFramesDumpThreshold = userDefault.cpuTraceStackFramesDumpThreshold;
    [tracer startTracing];
    [tracer addDelegate:self];

    // needed for remote symbolics
    [MTHawkeyeDyldImagesStorage asyncCacheDyldImagesInfoIfNeeded];
}

- (void)hawkeyeClientDidStop {
    MTHLogInfo(@"cpu trace stop");

    [[MTHCPUTrace shareInstance] stopTracing];
    [[MTHCPUTrace shareInstance] removeDelegate:self];
}

// MARK: - MTHCPUTracingDelegate
- (void)cpuHighLoadRecordStartAt:(NSTimeInterval)startAt
       didUpdateStackFrameSample:(MTH_CPUTraceStackFramesNode *)stackframeRootNode
                 averageCPUUsage:(CGFloat)averageCPUUsage
                     lastingTime:(CGFloat)lastingTime {
    if (self.currentRecord == nil) {
        self.currentRecord = [[MTHCPUTraceHighLoadRecord alloc] init];
    }

    self.currentRecord.startAt = startAt;
    self.currentRecord.lasting = lastingTime;
    self.currentRecord.averageCPUUsage = averageCPUUsage;

    _currentSampleStackFrame = stackframeRootNode;
}

- (void)cpuHighLoadRecordDidEnd {
    [self writeLivingRecordIfNeed];
}

- (void)writeLivingRecordIfNeed {
    if (self.currentRecord.startAt > 0) {
        [self storeCPUHighLoadRecord:self.currentRecord stackFramesSample:_currentSampleStackFrame];
        self.currentRecord = nil;
    }
}

// MARK: - Storage

- (void)storeCPUHighLoadRecord:(MTHCPUTraceHighLoadRecord *)record stackFramesSample:(MTH_CPUTraceStackFramesNode *)stackFramesSample {
    NSString *key = [NSString stringWithFormat:@"%.2f", record.startAt];

    NSMutableDictionary *recordDict = @{}.mutableCopy;
    recordDict[@"start"] = key;
    recordDict[@"lasting"] = [NSString stringWithFormat:@"%.2f", record.lasting];
    recordDict[@"average"] = [NSString stringWithFormat:@"%.2f", record.averageCPUUsage * 100];

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:recordDict options:0 error:nil];
    NSString *value = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    [[MTHawkeyeStorage shared] asyncStoreValue:value withKey:key inCollection:@"cpu-highload"];
    [self storeCPUHighLoadStackFramesSample:stackFramesSample withKey:key];
}

- (void)storeCPUHighLoadStackFramesSample:(MTH_CPUTraceStackFramesNode *)rootNode withKey:(NSString *)key {
    NSString *sampleInJSON = rootNode->jsonString();
    if (sampleInJSON.length > 0) {
        if ([sampleInJSON lengthOfBytesUsingEncoding:NSUTF8StringEncoding] < 15 * 1024) {
            [[MTHawkeyeStorage shared] asyncStoreValue:sampleInJSON withKey:key inCollection:@"cpu-highload-stackframe"];
        } else {
            [self _storeLongStackFramesInString:sampleInJSON withKey:key];
        }
    }
}

- (NSArray<MTHCPUTraceHighLoadRecord *> *)readHighLoadRecords {
    NSArray<NSString *> *keys;
    NSArray<NSString *> *values;
    [[MTHawkeyeStorage shared] readKeyValuesInCollection:@"cpu-highload" keys:&keys values:&values];

    NSMutableArray<MTHCPUTraceHighLoadRecord *> *records = @[].mutableCopy;
    for (NSString *value in values) {
        NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (dict) {
            MTHCPUTraceHighLoadRecord *record = [[MTHCPUTraceHighLoadRecord alloc] init];
            record.startAt = [dict[@"start"] doubleValue];
            record.lasting = [dict[@"lasting"] doubleValue];
            record.averageCPUUsage = [dict[@"average"] doubleValue];
            [records addObject:record];
        } else {
            MTHLogWarn(@"read cpu high load record failed");
        }
    }
    return [records copy];
}

- (NSDictionary *)readCPUHighLoadStackFramesRecordsDict {
    NSArray *aKeys;
    NSArray *aValues;
    [[MTHawkeyeStorage shared] readKeyValuesInCollection:@"cpu-highload-stackframe" keys:&aKeys values:&aValues];

    NSMutableArray *bKeys = @[].mutableCopy;
    NSMutableArray *bValues = @[].mutableCopy;
    NSArray<NSArray<NSString *> *> *bKeyValues = [self _readLongStackFramesFromFile];
    for (NSArray<NSString *> *keyValue in bKeyValues) {
        if (keyValue.count != 2)
            continue;

        [bKeys addObject:keyValue[0]];
        [bValues addObject:keyValue[1]];
    }

    NSMutableDictionary *dict = @{}.mutableCopy;
    for (NSInteger i = 0; i < aKeys.count && i < aValues.count; ++i) {
        dict[aKeys[i]] = aValues[i];
    }
    for (NSInteger i = 0; i < bKeys.count && i < bValues.count; ++i) {
        dict[bKeys[i]] = bValues[i];
    }

    return [dict copy];
}

- (void)_storeLongStackFramesInString:(NSString *)value withKey:(NSString *)key {
    dispatch_async([MTHawkeyeStorage shared].storeQueue, ^{
        @autoreleasepool {
            NSString *content = [NSString stringWithFormat:@"%@,%@·", key, value];
            NSString *path = [self longFilePath];
            if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
                [content writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:nil];
                return;
            }
            NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
            if (data) {
                NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:path];
                @try {
                    [fileHandle seekToEndOfFile];
                    [fileHandle writeData:data];
                } @catch (NSException *exception) {
                    MTHLogWarn("store cpu trace recorded frames failed: %@", exception);
                } @finally {
                    [fileHandle closeFile];
                }
            }
        }
    });
}

- (NSArray<NSArray<NSString *> *> *)_readLongStackFramesFromFile {
    __block NSArray<NSString *> *keyValueRecords = nil;

    dispatch_sync([MTHawkeyeStorage shared].storeQueue, ^{
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:[self longFilePath]];
        NSString *recordStr = [[NSString alloc] initWithData:[fileHandle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        keyValueRecords = [recordStr componentsSeparatedByString:@"·"];
    });
    __block NSMutableArray *records = @[].mutableCopy;
    [keyValueRecords enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        NSArray *keyValue = [obj componentsSeparatedByString:@","];
        [records addObject:keyValue];
    }];

    return records;
}

- (NSString *)longFilePath {
    NSString *path = [NSString stringWithFormat:@"%@/%@", [MTHawkeyeStorage shared].storeDirectory, @"cpu-highload-stackframe-ext"];
    return path;
}

// MARK: -
- (void)unObserveAppEnterBackground {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
}

- (void)observeAppEnterBackground {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *_Nonnull note) {
                                                      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                                          [self writeLivingRecordIfNeed];
                                                      });
                                                  }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *_Nonnull note) {
                                                      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                                          [self writeLivingRecordIfNeed];
                                                      });
                                                  }];
}

// MARK: - CPUTrace Setting Observer

- (void)observerCPUTraceHawkeyeSetting {
    __weak __typeof(self) weakSelf = self;
    [[MTHawkeyeUserDefaults shared] mth_addObserver:self
                                             forKey:NSStringFromSelector(@selector(cpuTraceOn))
                                        withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                                            if ([newValue boolValue])
                                                [weakSelf hawkeyeClientDidStart];
                                            else
                                                [weakSelf hawkeyeClientDidStop];
                                        }];
    [[MTHawkeyeUserDefaults shared] mth_addObserver:self
                                             forKey:NSStringFromSelector(@selector(cpuTraceHighLoadThreshold))
                                        withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                                            [MTHCPUTrace shareInstance].highLoadThreshold = [newValue doubleValue];
                                        }];
    [[MTHawkeyeUserDefaults shared] mth_addObserver:self
                                             forKey:NSStringFromSelector(@selector(cpuTraceCheckIntervalIdle))
                                        withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                                            [MTHCPUTrace shareInstance].checkIntervalIdle = [newValue doubleValue];
                                        }];
    [[MTHawkeyeUserDefaults shared] mth_addObserver:self
                                             forKey:NSStringFromSelector(@selector(cpuTraceCheckIntervalBusy))
                                        withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                                            [MTHCPUTrace shareInstance].checkIntervalBusy = [newValue doubleValue];
                                        }];
    [[MTHawkeyeUserDefaults shared] mth_addObserver:self
                                             forKey:NSStringFromSelector(@selector(cpuTraceHighLoadLastingLimit))
                                        withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                                            [MTHCPUTrace shareInstance].highLoadLastingLimit = [newValue doubleValue];
                                        }];
    [[MTHawkeyeUserDefaults shared] mth_addObserver:self
                                             forKey:NSStringFromSelector(@selector(cpuTraceStackFramesDumpThreshold))
                                        withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                                            [MTHCPUTrace shareInstance].stackFramesDumpThreshold = [newValue doubleValue];
                                        }];
}

- (void)unobserverCPUTraceHawkeyeSetting {
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(cpuTraceOn))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(cpuTraceHighLoadThreshold))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(cpuTraceCheckIntervalIdle))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(cpuTraceHighLoadLastingLimit))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(cpuTraceStackFramesDumpThreshold))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(cpuTraceCheckIntervalBusy))];
}

@end

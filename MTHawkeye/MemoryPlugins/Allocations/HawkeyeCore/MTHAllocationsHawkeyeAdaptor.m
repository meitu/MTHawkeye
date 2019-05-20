//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/17
// Created by: EuanC
//


#import "MTHAllocationsHawkeyeAdaptor.h"
#import "MTHAllocations.h"
#import "MTHawkeyeLogMacros.h"
#import "MTHawkeyeUserDefaults+Allocations.h"
#import "MTHawkeyeUtility.h"


@interface MTHAllocationsHawkeyeAdaptor ()

@end


@implementation MTHAllocationsHawkeyeAdaptor

- (void)dealloc {
    [self unobserverAllocationsHawkeyeSetting];
}

- (instancetype)init {
    if ((self = [super init])) {
        [self observerAllocationsHawkeyeSetting];
    }
    return self;
}

// MARK: - MTHawkeyePlugin

+ (NSString *)pluginID {
    return @"allocations";
}

- (void)hawkeyeClientDidStart {
    if (![MTHawkeyeUserDefaults shared].allocationsTraceOn)
        return;

    [MTHAllocationsHawkeyeAdaptor startAllocationsTracer];

    if ([MTHawkeyeUserDefaults shared].chunkMallocTraceOn) {
        [MTHAllocationsHawkeyeAdaptor startSingleChunkMallocTracer];
    }
}

- (void)hawkeyeClientDidStop {
    [MTHAllocationsHawkeyeAdaptor stopAllocationsTracer];
    [MTHAllocationsHawkeyeAdaptor stopSingleChunkMallocTracer];
}

- (void)receivedFlushStatusCommand {
    if ([MTHAllocations shared].isLoggingOn) {
        static NSInteger preAllocationsMemUsage = 0;
        if (preAllocationsMemUsage != [MTHAllocations shared].assistantMmapMemoryUsed) {
            preAllocationsMemUsage = [MTHAllocations shared].assistantMmapMemoryUsed;
            MTHLogInfo(@"allocations-mmap-usage: %.0fMB", [MTHAllocations shared].assistantMmapMemoryUsed / 1024.f / 1024.f);
            MTHLogInfo(@"allocations-heap-usage: %.0fMB", [MTHAllocations shared].assistantHeapMemoryUsage / 1024.f / 1024.f);
        }
    }
}

// MARK: server
+ (void)startAllocationsTracer {
    MTHAllocations *allocations = [MTHAllocations shared];
    MTHawkeyeUserDefaults *defaults = [MTHawkeyeUserDefaults shared];

    allocations.isStackLogNeedSysFrame = defaults.isStackLogNeedSysFrame;
    NSString *recordsFilesDir = [[MTHawkeyeUtility currentStorePath] stringByAppendingPathComponent:@"allocations"];
    [allocations setupPersistanceDirectory:recordsFilesDir];

    if (![MTHAllocations shared].isLoggingOn) {
        [allocations startMallocLogging:YES vmLogging:YES];

        MTHLogInfo(@"allocations logger start");
    }

    if (defaults.mallocReportThresholdInBytes > 0)
        allocations.mallocReportThresholdInBytes = defaults.mallocReportThresholdInBytes;
    if (defaults.vmAllocateReportThresholdInBytes > 0)
        allocations.vmReportThresholdInBytes = defaults.vmAllocateReportThresholdInBytes;
}

+ (void)stopAllocationsTracer {
    if (![MTHAllocations shared].isLoggingOn)
        return;

    [[MTHAllocations shared] stopMallocLogging:YES vmLogging:YES];

    MTHLogInfo(@"allocations logger stop");
}

+ (void)startSingleChunkMallocTracer {
    if ([MTHAllocations shared].isLoggingOn)
        return;

    [[MTHAllocations shared]
        startSingleChunkMallocDetector:[MTHawkeyeUserDefaults shared].chunkMallocThresholdInBytes
                              callback:^(size_t bytes, vm_address_t *_Nonnull stack_frames, size_t frames_count) {
                                  MTHLogInfo(@"chunk malloc:%.2fmb stack: ", bytes / 1024 / 1024.f);
                              }];

    MTHLogInfo(@"allocations single chunk malloc start");
}

+ (void)stopSingleChunkMallocTracer {
    if (![MTHAllocations shared].isLoggingOn)
        return;

    [[MTHAllocations shared] stopSingleChunkMallocDetector];
    MTHLogInfo(@"allocations single chunk malloc stop");
}

// MARK: - Allocations Setting Observer
- (void)observerAllocationsHawkeyeSetting {
    __weak __typeof(self) weakSelf = self;
    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(allocationsTraceOn))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                if ([newValue boolValue])
                    [weakSelf hawkeyeClientDidStart];
                else
                    [weakSelf hawkeyeClientDidStop];
            }];

    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(mallocReportThresholdInBytes))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                [MTHAllocations shared].mallocReportThresholdInBytes = [newValue integerValue];
            }];

    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(vmAllocateReportThresholdInBytes))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                [MTHAllocations shared].vmReportThresholdInBytes = [newValue integerValue];
            }];

    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(reportCategoryElementCountThreshold))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                [MTHAllocations shared].reportCategoryElementCountThreshold = [newValue integerValue];
            }];

    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(isStackLogNeedSysFrame))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                [[MTHAllocations shared] setIsStackLogNeedSysFrame:[newValue boolValue]];
            }];

    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(maxStackRecordDepth))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                [[MTHAllocations shared] setMaxStackRecordDepth:[newValue integerValue]];
            }];

    // single chunk malloc.
    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(chunkMallocTraceOn))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                if ([newValue boolValue])
                    [MTHAllocationsHawkeyeAdaptor startSingleChunkMallocTracer];
                else
                    [MTHAllocationsHawkeyeAdaptor stopSingleChunkMallocTracer];
            }];

    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(chunkMallocThresholdInBytes))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                [[MTHAllocations shared] configSingleChunkMallocThresholdInBytes:[newValue integerValue]];
            }];
}

- (void)unobserverAllocationsHawkeyeSetting {
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(allocationsTraceOn))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(mallocReportThresholdInBytes))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(vmAllocateReportThresholdInBytes))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(reportCategoryElementCountThreshold))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(isStackLogNeedSysFrame))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(maxStackRecordDepth))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(chunkMallocTraceOn))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(chunkMallocThresholdInBytes))];
}

@end

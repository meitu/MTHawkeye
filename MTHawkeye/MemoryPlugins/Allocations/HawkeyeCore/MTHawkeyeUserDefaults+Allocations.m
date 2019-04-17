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


#import "MTHAllocations.h"
#import "MTHawkeyeUserDefaults+Allocations.h"

@implementation MTHawkeyeUserDefaults (Allocations)

- (void)setAllocationsTraceOn:(BOOL)allocationsTraceOn {
    [self setObject:@(allocationsTraceOn) forKey:NSStringFromSelector(@selector(allocationsTraceOn))];
}

- (BOOL)allocationsTraceOn {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(allocationsTraceOn))];
    return value ? value.boolValue : NO;
}

- (void)setMallocReportThresholdInBytes:(size_t)mallocReportThresholdInBytes {
    [self setObject:@(mallocReportThresholdInBytes) forKey:NSStringFromSelector(@selector(mallocReportThresholdInBytes))];
}

- (size_t)mallocReportThresholdInBytes {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(mallocReportThresholdInBytes))];
    return value ? [value integerValue] : [MTHAllocations shared].mallocReportThresholdInBytes;
}

- (void)setVmAllocateReportThresholdInBytes:(size_t)vmAllocateReportThresholdInBytes {
    [self setObject:@(vmAllocateReportThresholdInBytes) forKey:NSStringFromSelector(@selector(vmAllocateReportThresholdInBytes))];
}

- (size_t)vmAllocateReportThresholdInBytes {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(vmAllocateReportThresholdInBytes))];
    return value ? [value integerValue] : [MTHAllocations shared].vmReportThresholdInBytes;
}

- (void)setReportCategoryElementCountThreshold:(uint32_t)reportCategoryElementCountThreshold {
    [self setObject:@(reportCategoryElementCountThreshold) forKey:NSStringFromSelector(@selector(reportCategoryElementCountThreshold))];
}

- (uint32_t)reportCategoryElementCountThreshold {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(reportCategoryElementCountThreshold))];
    return value ? (uint32_t)[value integerValue] : 0;
}

- (void)setChunkMallocTraceOn:(BOOL)chunkMallocTraceOn {
    [self setObject:@(chunkMallocTraceOn) forKey:NSStringFromSelector(@selector(chunkMallocTraceOn))];
}

- (BOOL)chunkMallocTraceOn {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(chunkMallocTraceOn))];
    return value ? value.boolValue : NO;
}

- (void)setChunkMallocThresholdInBytes:(size_t)chunkMallocThresholdInBytes {
    [self setObject:@(chunkMallocThresholdInBytes) forKey:NSStringFromSelector(@selector(chunkMallocThresholdInBytes))];
}

- (size_t)chunkMallocThresholdInBytes {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(chunkMallocThresholdInBytes))];
    return value ? (uint32_t)[value integerValue] : 1024 * 1024 * 1;
}

- (void)setIsStackLogNeedSysFrame:(BOOL)isStackLogNeedSysFrame {
    [self setObject:@(isStackLogNeedSysFrame) forKey:NSStringFromSelector(@selector(isStackLogNeedSysFrame))];
}

- (BOOL)isStackLogNeedSysFrame {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(isStackLogNeedSysFrame))];
    return value ? value.boolValue : NO;
}

- (void)setMaxStackRecordDepth:(size_t)maxStackRecordDepth {
    [self setObject:@(maxStackRecordDepth) forKey:NSStringFromSelector(@selector(maxStackRecordDepth))];
}

- (size_t)maxStackRecordDepth {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(maxStackRecordDepth))];
    return value ? [value integerValue] : 50;
}

@end

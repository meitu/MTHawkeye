//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/11/13
// Created by: EuanC
//


#import "MTHAHistoryRecordReader.h"
#import "MTHawkeyeDyldImagesUtils.h"

#import "mth_thread_utils.h"
#import "mtha_allocate_logging.h"
#import "mtha_allocate_record_output.h"
#import "mtha_allocate_record_reader.h"
#import "mtha_inner_log.h"

#import <list>


using namespace MTHAllocation;

@interface MTHAHistoryRecordReader ()

@property (nonatomic, copy) NSString *recordDir;

@end


@implementation MTHAHistoryRecordReader

+ (NSString *)mallocReportFileName {
    return @"malloc_report";
}

+ (NSString *)vmReportFileName {
    return @"vm_report";
}

- (instancetype)initWithRecordDir:(NSString *)rootDir {
    if (self = [super init]) {
        _recordDir = rootDir;
    }
    return self;
}

- (void)generateReportWithMallocThresholdInBytes:(NSInteger)mallocReportThresholdInBytes
                              vmThresholdInBytes:(NSInteger)vmReportThresholdInBytes {
    NSString *mallocReportPath = [self mallocReportPath];
    NSString *vmReportPath = [self vmReportPath];

    // read exist reports
    NSDictionary *mallocReport = [self reportAtFilePath:mallocReportPath];
    NSDictionary *vmReport = [self reportAtFilePath:vmReportPath];
    NSInteger existMallocReportThreshold = [mallocReport[@"threshold"] integerValue];
    NSInteger existVMReportThreshold = [vmReport[@"threshold"] integerValue];

    if (existMallocReportThreshold == mallocReportThresholdInBytes && existVMReportThreshold == vmReportThresholdInBytes) {
        // we don't need to regenerate cause the raw file doesn't change.
        return;
    }

    // clear exist reports.
    NSError *error;
    if ([[NSFileManager defaultManager] fileExistsAtPath:mallocReportPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:mallocReportPath error:&error];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:vmReportPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:vmReportPath error:&error];
    }
    if (error) {
        MTHLogWarn("remove malloc/vm report file failed, %@", error);
    }

    [self doGenerateReportWithMallocThreshold:mallocReportThresholdInBytes vmThreshold:vmReportThresholdInBytes];
}

- (NSDictionary *)reportAtFilePath:(NSString *)reportFile {
    if (![[NSFileManager defaultManager] fileExistsAtPath:reportFile]) {
        return nil;
    }

    NSError *error;
    NSString *content = [NSString stringWithContentsOfFile:reportFile encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        MTHLogWarn(@"read allocations report file content failed, %@", error);
        return nil;
    }

    NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *report = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    if (error) {
        MTHLogWarn(@"read allocations report file content, json serialization failed, %@", error);
    }
    return report;
}

- (void)doGenerateReportWithMallocThreshold:(NSInteger)mallocThreshold
                                vmThreshold:(NSInteger)vmThreshold {
    bool loggingRunning = mtha_memory_allocate_logging_enabled;
    if (loggingRunning) {
        mtha_memory_allocate_logging_lock();
        mtha_memory_allocate_logging_enabled = false;
    }

    NSString *stackTableRecordPath = [self.recordDir stringByAppendingFormat:@"/%s", mtha_stacks_records_filename];
    mtha_backtrace_uniquing_table *stackTable = mtha_read_uniquing_table_from([stackTableRecordPath UTF8String]);

    // generate malloc report
    NSString *mallocRecordPath = [self.recordDir stringByAppendingFormat:@"/%s", mtha_malloc_records_filename];
    mtha_splay_tree *mallocRecord = mtha_splay_tree_read_from_mmapfile([mallocRecordPath UTF8String]);
    [self generateFromMemoryRecords:mallocRecord stackRecords:stackTable toReportFilePath:[self mallocReportPath] withThreshold:mallocThreshold];
    mtha_splay_tree_close(mallocRecord);

    // generate vm report
    NSString *vmRecordPath = [self.recordDir stringByAppendingFormat:@"/%s", mtha_vm_records_filename];
    mtha_splay_tree *vmRecord = mtha_splay_tree_read_from_mmapfile([vmRecordPath UTF8String]);
    [self generateFromMemoryRecords:vmRecord stackRecords:stackTable toReportFilePath:[self vmReportPath] withThreshold:vmThreshold];
    mtha_splay_tree_close(vmRecord);

    mtha_destroy_uniquing_table(stackTable);

    if (loggingRunning) {
        mtha_memory_allocate_logging_enabled = true;
        mtha_memory_allocate_logging_unlock();
    }
}

- (void)generateFromMemoryRecords:(mtha_splay_tree *)rawRecords
                     stackRecords:(mtha_backtrace_uniquing_table *)stackRecords
                 toReportFilePath:(NSString *)reportPath
                    withThreshold:(NSInteger)threshold {

    AllocateRecords allocateRecords(rawRecords);
    allocateRecords.parseAndGroupingRawRecords();

    RecordOutput output(allocateRecords, stackRecords);
    output.flushReportToFileFormatInJson((uint32_t)threshold, reportPath, [self dyldImagesPath]);
}

- (NSString *)mallocReportPath {
    return [self.recordDir stringByAppendingPathComponent:MTHAHistoryRecordReader.mallocReportFileName];
}

- (NSString *)vmReportPath {
    return [self.recordDir stringByAppendingPathComponent:MTHAHistoryRecordReader.vmReportFileName];
}

- (NSString *)dyldImagesPath {
    return [self.recordDir stringByAppendingPathComponent:@"dyld-images"];
}

- (NSString *)mallocReportContent {
    NSError *error;
    NSString *content = [NSString stringWithContentsOfFile:[self mallocReportPath] encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        MTHLogWarn(@"Allocations read malloc report failed, %@", error);
        return nil;
    }
    return content;
}

- (NSString *)vmReportContent {
    NSError *error;
    NSString *content = [NSString stringWithContentsOfFile:[self vmReportPath] encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        MTHLogWarn(@"Allocations read vm report failed, %@", error);
        return nil;
    }
    return content;
}

- (NSString *)dyldImagesContent {
    NSError *error;
    NSString *content = [NSString stringWithContentsOfFile:[self dyldImagesPath] encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        MTHLogWarn(@"Allocations read dyld images info failed, %@", error);
        return nil;
    }
    return content;
}

@end

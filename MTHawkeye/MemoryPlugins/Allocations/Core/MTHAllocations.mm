//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/11/2
// Created by: EuanC
//


#import "MTHAllocations.h"

#import "MTHawkeyeDyldImagesUtils.h"

#import "NSObject+MTHAllocTrack.h"
#import "mth_thread_utils.h"
#import "mtha_allocate_logging.h"
#import "mtha_allocate_record_output.h"
#import "mtha_allocate_record_reader.h"
#import "mtha_inner_log.h"

#import <list>

using namespace MTHAllocation;

// MARK: - Malloc Category Record
extern bool __CFOASafe;
extern void (*__CFObjectAllocSetLastAllocEventNameFunction)(void *, const char *);
void (*MTHA_ORIGINAL___CFObjectAllocSetLastAllocEventNameFunction)(void *, const char *) = NULL;

extern void mtha_cfobject_alloc_set_last_alloc_event_name_function(void *, const char *);

extern void observeObjcObjectAllocationEventName(void);

extern void mtha_set_last_allocation_event_name(void *ptr, const char *classname);

#define kMTHAllocationsMallocReportFileName @"malloc_report"
#define kMTHAllocationsVMReportFileName @"vm_report"

// MARK: allication event name
void mtha_set_last_allocation_event_name(void *ptr, const char *classname) {
    if (!mtha_memory_allocate_logging_enabled || mtha_recording == nullptr) {
        return;
    }

    mtha_memory_allocate_logging_lock();
    // find record and set category.
    uint32_t idx = 0;
    if (mtha_recording->malloc_records != nullptr)
        idx = mtha_splay_tree_search(mtha_recording->malloc_records, (vm_address_t)ptr, false);

    if (idx > 0) {
        mtha_splay_tree_node *node = &mtha_recording->malloc_records->node[idx];
        size_t size = MTH_ALLOCATIONS_SIZE(node->category_and_size);
        node->category_and_size = MTH_ALLOCATIONS_CATEGORY_AND_SIZE((uint64_t)classname, size);
    } else {
        uint32_t vm_idx = 0;
        if (mtha_recording->vm_records != nullptr)
            vm_idx = mtha_splay_tree_search(mtha_recording->vm_records, (vm_address_t)ptr, false);

        if (vm_idx > 0) {
            mtha_splay_tree_node *node = &mtha_recording->vm_records->node[vm_idx];
            size_t size = MTH_ALLOCATIONS_SIZE(node->category_and_size);
            node->category_and_size = MTH_ALLOCATIONS_CATEGORY_AND_SIZE((uint64_t)classname, size);
        }
    }
    mtha_memory_allocate_logging_unlock();
}

void mtha_cfobject_alloc_set_last_alloc_event_name_function(void *ptr, const char *classname) {
    if (MTHA_ORIGINAL___CFObjectAllocSetLastAllocEventNameFunction) {
        MTHA_ORIGINAL___CFObjectAllocSetLastAllocEventNameFunction(ptr, classname);
    }

    mtha_set_last_allocation_event_name(ptr, classname);
}

// MARK: -

@interface MTHAllocations ()

@property (nonatomic, copy) NSString *logDir;
@property (nonatomic, copy) NSString *stacksLogName;
@property (nonatomic, copy) NSString *mallocPtrsLogName;
@property (nonatomic, copy) NSString *vmPtrsLogName;

@property (nonatomic, copy) NSString *mallocReportName;
@property (nonatomic, copy) NSString *vmReportName;

@end


@implementation MTHAllocations

+ (instancetype)shared {
    static MTHAllocations *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });

    return _sharedInstance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _mallocReportThresholdInBytes = 1024 * 500;  // 500KB
        _vmReportThresholdInBytes = 1024 * 1024 * 1; // 1MB
    }
    return self;
}

- (void)setIsStackLogNeedSysFrame:(BOOL)isStackLogNeedSysFrame {
    mth_allocations_need_sys_frame = isStackLogNeedSysFrame;
}

- (void)setMaxStackRecordDepth:(NSInteger)maxStackRecordDepth {
    mth_allocations_stack_record_max_depth = (uint32_t)maxStackRecordDepth;
}

- (void)setMallocReportThresholdInBytes:(NSInteger)mallocReportThresholdInBytes {
    _mallocReportThresholdInBytes = mallocReportThresholdInBytes;
}

- (void)setVmReportThresholdInBytes:(NSInteger)vmReportThresholdInBytes {
    _vmReportThresholdInBytes = vmReportThresholdInBytes;
}

- (NSInteger)assistantHeapMemoryUsage {
    return 0;
}

- (NSInteger)assistantMmapMemoryUsed {
    uint32_t size = 0;
    if (mtha_recording && mtha_recording->malloc_records) {
        size += mtha_recording->malloc_records->mmap_size;
    }
    if (mtha_recording && mtha_recording->vm_records) {
        size += mtha_recording->vm_records->mmap_size;
    }
    if (mtha_recording && mtha_recording->backtrace_records) {
        size += mtha_recording->backtrace_records->fileSize;
    }
    return size;
}

- (BOOL)setupPersistanceDirectory:(NSString *)dir {
    self.logDir = dir;

    NSError *error;
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.logDir]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:self.logDir withIntermediateDirectories:YES attributes:nil error:&error]) {
            MTHLogWarn(@"[hawkeye] create directory %@ failed, %@ %@", self.logDir, @(error.code), error.localizedDescription);
            return NO;
        }
    }

    return YES;
}

- (BOOL)isLoggingOn {
    return mtha_memory_allocate_logging_enabled;
}

- (BOOL)existLoggingRecords {
    return mtha_recording && (mtha_recording->backtrace_records && (mtha_recording->malloc_records || mtha_recording->vm_records));
}

- (BOOL)startMallocLogging:(BOOL)mallocLogOn vmLogging:(BOOL)vmLogOn {
#if TARGET_IPHONE_SIMULATOR
    return NO;
    // Only for device
#else // TARGET_IPHONE_SIMULATOR
    NSAssert(self.logDir.length > 0, @"You should conigure persistance directory before start malloc logging");

    strcpy(mtha_records_cache_dir, [self.logDir UTF8String]);

    mtha_memory_allocate_logging_enabled = true;

    mtha_prepare_memory_allocate_logging();

    if (mallocLogOn) {
        malloc_logger = (mtha_malloc_logger_t *)mtha_allocate_logging;
    }

    if (vmLogOn) {
        __syscall_logger = mtha_allocate_logging;
    }

    if (mallocLogOn || vmLogOn) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            __CFOASafe = true;
            MTHA_ORIGINAL___CFObjectAllocSetLastAllocEventNameFunction = __CFObjectAllocSetLastAllocEventNameFunction;
            __CFObjectAllocSetLastAllocEventNameFunction = mtha_cfobject_alloc_set_last_alloc_event_name_function;

            mtha_allocation_event_logger = mtha_set_last_allocation_event_name;
            [NSObject mtha_startAllocTrack];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.f * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSString *dyldDumperPath = [self.logDir stringByAppendingPathComponent:@"dyld-images"];
                if (![[NSFileManager defaultManager] fileExistsAtPath:dyldDumperPath]) {
                    mtha_setup_dyld_images_dumper_with_path(dyldDumperPath);
                }
            });
        });
    }

    return YES;
#endif
}

- (BOOL)stopMallocLogging:(BOOL)mallocLogOff vmLogging:(BOOL)vmLogOff {
    mtha_memory_allocate_logging_enabled = false;

    if (mallocLogOff) {
        malloc_logger = nullptr;
    }

    if (vmLogOff) {
        __syscall_logger = nullptr;
    }

    if (mtha_recording && mtha_recording->malloc_records) {
        mtha_splay_tree_close(mtha_recording->malloc_records);
        mtha_recording->malloc_records = nullptr;
    }
    if (mtha_recording && mtha_recording->vm_records) {
        mtha_splay_tree_close(mtha_recording->vm_records);
        mtha_recording->vm_records = nullptr;
    }
    if (mtha_recording && mtha_recording->backtrace_records) {
        mtha_destroy_uniquing_table(mtha_recording->backtrace_records);
        mtha_recording->backtrace_records = nullptr;
    }
    mtha_recording = nullptr;

    return YES;
}

- (void)startSingleChunkMallocDetector:(size_t)thresholdInBytes callback:(MTHVMChunkMallocBlock)callback {
    mtha_start_single_chunk_malloc_detector(thresholdInBytes, ^(size_t bytes, vm_address_t *stack_frames, size_t frames_count) {
        if (callback) {
            callback(bytes, stack_frames, frames_count);
        }
    });
}

- (void)configSingleChunkMallocThresholdInBytes:(size_t)thresholdInBytes {
    mtha_config_single_chunk_malloc_threshold(thresholdInBytes);
}

- (void)stopSingleChunkMallocDetector {
    mtha_stop_single_chunk_malloc_detector();
}

- (NSString *)mallocReportFileContent {
    NSString *path = [self.logDir stringByAppendingPathComponent:kMTHAllocationsMallocReportFileName];
    NSError *error;
    NSStringEncoding encoding;
    return [NSString stringWithContentsOfFile:path usedEncoding:&encoding error:&error] ?: @"";
}

- (NSString *)vmReportFileContent {
    NSString *path = [self.logDir stringByAppendingPathComponent:kMTHAllocationsVMReportFileName];
    NSError *error;
    NSStringEncoding encoding;
    return [NSString stringWithContentsOfFile:path usedEncoding:&encoding error:&error] ?: @"";
}

- (NSString *)dyldImagesContent {
    NSError *error;
    NSString *path = [self.logDir stringByAppendingPathComponent:@"dyld-images"];
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        MTHLogWarn(@"Allocations read dyld images info failed, %@", error);
        return nil;
    }
    return content;
}

- (void)generateReportAndSaveToFile {
    [self _generateReportAndFlushToConsoleOrFile:NO jsonStyleForFile:NO];
}

- (void)generateReportAndFlushToConsole {
    [self _generateReportAndFlushToConsoleOrFile:YES jsonStyleForFile:NO];
}

- (void)generateReportAndSaveToFileInJSON {
    [self _generateReportAndFlushToConsoleOrFile:NO jsonStyleForFile:YES];
}

- (void)_generateReportAndFlushToConsoleOrFile:(BOOL)toConsole jsonStyleForFile:(BOOL)inJSONStyle {
    // 1. 加锁，确定所有记录中的操作完成
    if (mtha_recording == NULL || mtha_recording->malloc_records == NULL) {
        return;
    }

    bool isLoggingRun = mtha_memory_allocate_logging_enabled;
    if (isLoggingRun) {
        mtha_memory_allocate_logging_lock();
        mtha_memory_allocate_logging_enabled = false;
    }

    // 2. 挂起所有线程
    mth_suspend_all_child_threads();

    mtha_backtrace_uniquing_table *stacksRecord = mtha_recording->backtrace_records;

    // 3. read records.
    // malloc records.
    if (mtha_recording->malloc_records) {
        AllocateRecords allocateRecords(mtha_recording->malloc_records);
        allocateRecords.parseAndGroupingRawRecords();

        RecordOutput output(allocateRecords, stacksRecord, (uint32_t)self.reportCategoryElementCountThreshold);
        uint32_t mallocThreshold = (uint32_t)self.mallocReportThresholdInBytes;
        if (toConsole) {
            printf("[hawkeye] ---------------------------\n");
            printf("[hawkeye] DefaultMallocZone(Heap) report: \n");
            printf("[hawkeye] report threshold: %.2fKB \n\n", mallocThreshold / 1024.f);
            output.flushReportToConsoleFormatInLine(mallocThreshold);
        } else {
            NSString *outputPath = [self.logDir stringByAppendingPathComponent:kMTHAllocationsMallocReportFileName];
            if (inJSONStyle)
                output.flushReportToFileFormatInJson(mallocThreshold, outputPath, nil);
            else
                output.flushReportToFileFormatInLine(mallocThreshold, outputPath);
        }
    }

    if (toConsole) {
        printf("\n[hawkeye] ---------------------------\n\n");
    }

    // vm reports.
    if (mtha_recording->vm_records) {
        if (toConsole) {
            printf("[hawkeye] virtual memory(vmallocate/mmap ...) report: \n");
            printf("[hawkeye] report threshold: %.2fKB \n\n", self.vmReportThresholdInBytes / 1024.f);
        }

        AllocateRecords allocateRecords(mtha_recording->vm_records);
        allocateRecords.parseAndGroupingRawRecords();

        RecordOutput output(allocateRecords, stacksRecord, (uint32_t)self.reportCategoryElementCountThreshold);
        uint32_t vmThreshold = (uint32_t)self.vmReportThresholdInBytes;
        if (toConsole) {
            output.flushReportToConsoleFormatInLine(vmThreshold);
        } else {
            NSString *outputPath = [self.logDir stringByAppendingPathComponent:kMTHAllocationsVMReportFileName];
            if (inJSONStyle)
                output.flushReportToFileFormatInJson(vmThreshold, outputPath, nil);
            else
                output.flushReportToFileFormatInLine(vmThreshold, outputPath);
        }
    }

    if (toConsole) {
        printf("\n[hawkeye] ---------------------------\n\n");
    }

    // 4. 恢复所有线程
    mth_resume_all_child_threads();

    // 5. 释放锁
    if (isLoggingRun) {
        mtha_memory_allocate_logging_enabled = true;
        mtha_memory_allocate_logging_unlock();
    }
}

@end

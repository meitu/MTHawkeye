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


#import <Foundation/Foundation.h>
#import <mach/vm_types.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^MTHVMChunkMallocBlock)(size_t bytes, vm_address_t *stack_frames, size_t frames_count);

@interface MTHAllocations : NSObject

@property (nonatomic, assign) NSInteger mallocReportThresholdInBytes; /**< malloc report generating threshold in bytes */
@property (nonatomic, assign) NSInteger vmReportThresholdInBytes;     /**< vmallocte/mmap report generating threshold in bytes */

/**
 when the category's allocation size within the limit, use this to limit the category output.
 or all the category summary will output to the report.

 default 0.
 */
@property (nonatomic, assign) NSInteger reportCategoryElementCountThreshold;

@property (nonatomic, assign, readonly) NSInteger assistantHeapMemoryUsage; /**< extra heap memory used by Allocations */
@property (nonatomic, assign, readonly) NSInteger assistantMmapMemoryUsed;  /**< extra mmap memory used by Allocations */

+ (instancetype)shared;

/**
 setup root directory path for record files.
 You should call this method before you start the logger.
 You should set unique persistance directories for each session.
 */
- (BOOL)setupPersistanceDirectory:(NSString *)rootDir;

- (void)setIsStackLogNeedSysFrame:(BOOL)isStackLogNeedSysFrame; /**< record system libraries frames when record backtrace, default false */
- (void)setMaxStackRecordDepth:(NSInteger)maxStackRecordDepth;  /**< stack record max depth, default 50 */

- (BOOL)isLoggingOn;
- (BOOL)existLoggingRecords;

- (BOOL)startMallocLogging:(BOOL)mallocLogOn vmLogging:(BOOL)vmLogOn;
- (BOOL)stopMallocLogging:(BOOL)mallocLogOff vmLogging:(BOOL)vmLogOff;

- (void)startSingleChunkMallocDetector:(size_t)thresholdInBytes callback:(MTHVMChunkMallocBlock)callback;
- (void)configSingleChunkMallocThresholdInBytes:(size_t)thresholdInBytes;
- (void)stopSingleChunkMallocDetector;


/**
 Read record from memory, then generate report and flush to file.

 while generate malloc report, only record size exceed `mallocReportThresholdInBytes` will be counted.
 whild generate vm report, only record size exceed `vmReportThresholdInBytes` will be counted.

 you can change `mallocReportThresholdInBytes`, `vmReportThresholdInBytes` before generate report.
 */
- (void)generateReportAndSaveToFile;

/**
 In Json Style.
 */
- (void)generateReportAndSaveToFileInJSON;

/**
 read the report file content generate by `generateReportAndSaveToFile` function.
 */
- (NSString *)mallocReportFileContent;
- (NSString *)vmReportFileContent;
- (NSString *)dyldImagesContent;

/**
 Read record from memory, then generate report and flush to console.

 while generate malloc report, only record size exceed `mallocReportThresholdInBytes` will be counted.
 whild generate vm report, only record size exceed `vmReportThresholdInBytes` will be counted.

 you can change `mallocReportThresholdInBytes`, `vmReportThresholdInBytes` before generate report.
 */
- (void)generateReportAndFlushToConsole;

@end

NS_ASSUME_NONNULL_END

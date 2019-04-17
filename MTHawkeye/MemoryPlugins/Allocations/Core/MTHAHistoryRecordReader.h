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


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTHAHistoryRecordReader : NSObject

@property (nonatomic, copy, class, readonly) NSString *mallocReportFileName;
@property (nonatomic, copy, class, readonly) NSString *vmReportFileName;

- (instancetype)initWithRecordDir:(NSString *)rootDir;


/**
 Read record from persistance files, then generate report and save to files.

 while generate malloc report, only record size exceed `mallocReportThresholdInBytes` will be counted.
 whild generate vm report, only record size exceed `vmReportThresholdInBytes` will be counted.

 ( ./malloc_records + ./stacks ) => ./malloc_report
 ( ./vm_records     + ./stacks ) => ./vm_report

 */
- (void)generateReportWithMallocThresholdInBytes:(NSInteger)mallocReportThresholdInBytes
                              vmThresholdInBytes:(NSInteger)vmReportThresholdInBytes;

- (NSString *)mallocReportContent;
- (NSString *)vmReportContent;
- (NSString *)dyldImagesContent;

@end

NS_ASSUME_NONNULL_END

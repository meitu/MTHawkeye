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


#import "MTHawkeyeUserDefaults.h"

NS_ASSUME_NONNULL_BEGIN

@interface MTHawkeyeUserDefaults (Allocations)

@property (nonatomic, assign) BOOL allocationsTraceOn;                      /**< 监控通过内存分配记录及堆栈 */
@property (nonatomic, assign) size_t mallocReportThresholdInBytes;          /**< 读取内存分配记录时，输出 malloc 报告的阈值 */
@property (nonatomic, assign) size_t vmAllocateReportThresholdInBytes;      /**< 读取内存分配记录时，输出 vmallocation/mmap 报告的阈值 */
@property (nonatomic, assign) uint32_t reportCategoryElementCountThreshold; /**< limit the category summary report, default 0 */
@property (nonatomic, assign) BOOL chunkMallocTraceOn;                      /**< 单次大块内存分配监控 */
@property (nonatomic, assign) size_t chunkMallocThresholdInBytes;           /**< 单次大块内存分配监控阈值 */

@property (nonatomic, assign) BOOL isStackLogNeedSysFrame; /**< 堆栈记录时，是否记录非 App 帧 */
@property (nonatomic, assign) size_t maxStackRecordDepth;  /**< 记录堆栈的最深深度，默认 50 */

@end

NS_ASSUME_NONNULL_END

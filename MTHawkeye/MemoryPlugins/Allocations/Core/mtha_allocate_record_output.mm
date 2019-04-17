//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/10/17
// Created by: EuanC
//


#include "mtha_allocate_record_output.h"

#import "MTHStackFrameSymbolics.h"
#import "MTHawkeyeDyldImagesUtils.h"

#import "mtha_inner_log.h"

#import <malloc/malloc.h>

using namespace MTHAllocation;

static vm_address_t frames[MTH_ALLOCATIONS_MAX_STACK_SIZE];

static void flush_stack_records_to_output(
    void (*line_output)(char *line),
    AllocateRecords *allocateRecords,
    mtha_backtrace_uniquing_table *stackRecords,
    MTHStackFrameSymbolics *stackHelper,
    uint32_t thresholdInBytes,
    uint32_t categoryElementCountThreshold) {

    const int kMaxBufLength = 1024;
    char buf[kMaxBufLength];
    memset(buf, 0, kMaxBufLength);

    sprintf(buf, "[hawkeye] record_size: %.2fMB, allocates: %u, categories: %u, stacks: %u\n\n", allocateRecords->recordSize() / 1024.f / 1024.f, allocateRecords->allocateRecordCount(), allocateRecords->categoryRecordCount(), allocateRecords->stackRecordCount());
    line_output(buf);
    memset(buf, 0, kMaxBufLength);

    AllocateRecords::InCategory *log = allocateRecords->firstRecordInCategory();
    if (log == NULL)
        return;

    do {
        if (log->size < thresholdInBytes && log->count < categoryElementCountThreshold) {
            log = allocateRecords->nextRecordInCategory();
            continue;
        }

        if (log->size > 1024 * 1024)
            sprintf(buf, "+ size: %.3lfMB, ", (double)log->size / 1024 / 1024);
        else if (log->size > 1024)
            sprintf(buf, "+ size: %.3lfKB, ", (double)log->size / 1024);
        else
            sprintf(buf, "+ size: %ubyte, ", log->size);

        sprintf(buf + strlen(buf), "category: %s, stack_id_count: %lu, record_count: %u \n", log->name, log->stacks->size(), log->count);

        line_output(buf);
        memset(buf, 0, kMaxBufLength);

        if (log->size >= thresholdInBytes) {
            std::list<AllocateRecords::InStackId *> *stacks = log->stacks;
            for (auto sit = stacks->begin(); sit != stacks->end(); ++sit) {
                AllocateRecords::InStackId *stack = *sit;
                if (stack->size < thresholdInBytes)
                    break;

                if (stack->size > 1024 * 1024)
                    sprintf(buf, "> size: %.3lfMB, count:%d \n", (double)stack->size / 1024 / 1024, stack->count);
                else if (stack->size > 1024)
                    sprintf(buf, "> size: %.3lfKB, count:%d \n", (double)stack->size / 1024, stack->count);
                else
                    sprintf(buf, "> size: %ubyte, count:%d \n", stack->size, stack->count);

                line_output(buf);
                memset(buf, 0, kMaxBufLength);

                if (!stackRecords)
                    continue;

                // 获取分配内存时的调用堆栈
                uint32_t frame_count = 0;
                mtha_unwind_stack_from_table_index(stackRecords, stack->stack_id, frames, &frame_count, MTH_ALLOCATIONS_MAX_STACK_SIZE);
                for (uint32_t i = 0; i < frame_count; i++) {
                    vm_address_t addr = frames[i];
                    Dl_info dlinfo = {NULL, NULL, NULL, NULL};
                    stackHelper->getDLInfoByAddr(addr, &dlinfo, true);

                    if (dlinfo.dli_sname) {
                        sprintf(buf, "%u %s  %s\n", i, dlinfo.dli_fname ?: "unknown", dlinfo.dli_sname);
                    } else {
                        sprintf(buf, "%u %s %p %p, org: %p\n", i, dlinfo.dli_fname ?: "unknown", dlinfo.dli_fbase, dlinfo.dli_saddr, (void *)addr);
                    }

                    line_output(buf);
                    memset(buf, 0, kMaxBufLength);
                }

                sprintf(buf, "\n");
                line_output(buf);
                memset(buf, 0, kMaxBufLength);
            }
        }

        log = allocateRecords->nextRecordInCategory();
    } while (log != NULL);
}

// MARK: - c api

static void line_output_to_console(char *line) {
    printf("%s", line);
}

static NSFileHandle *output_file = nil;
static void line_output_to_file(char *line) {
    [output_file seekToEndOfFile];
    [output_file writeData:[NSData dataWithBytes:line length:strnlen(line, 2048)]];
}

static void flush_stack_records_to_console_in_line(
    AllocateRecords *allocateRecords,
    mtha_backtrace_uniquing_table *stackRecords,
    MTHStackFrameSymbolics *stackHelper,
    uint32_t thresholdInBytes,
    uint32_t categoryElementCountThreshold) {
    flush_stack_records_to_output(line_output_to_console, allocateRecords, stackRecords, stackHelper, thresholdInBytes, categoryElementCountThreshold);
}

static void flush_stack_records_to_file_in_line(
    AllocateRecords *allocateRecords,
    mtha_backtrace_uniquing_table *stackRecords,
    MTHStackFrameSymbolics *stackHelper,
    uint32_t thresholdInBytes,
    uint32_t categoryElementCountThreshold,
    NSString *filePath) {

    NSError *error;
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        if (error) {
            MTHLogWarn(@"Allocations remove current records file failed, %@", error);
        }
    }

    [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];

    output_file = [NSFileHandle fileHandleForWritingAtPath:filePath];

    flush_stack_records_to_output(line_output_to_file, allocateRecords, stackRecords, stackHelper, thresholdInBytes, categoryElementCountThreshold);

    output_file = nil;
}


static void flush_stack_records_to_file_in_json(
    AllocateRecords *allocationRecords,
    mtha_backtrace_uniquing_table *stackRecords,
    uint32_t thresholdInBytes,
    uint32_t categoryElementCountThreshold,
    NSString *filePath,
    NSString *dyldImagesInfoFile) {

    NSMutableArray *categories = [NSMutableArray array];
    AllocateRecords::InCategory *log = allocationRecords->firstRecordInCategory();
    if (log == NULL)
        return;

#ifdef DEBUG
    // we can't make the restore correct while developing.
    BOOL needRestoreFromDyldImages = NO;
#else
    BOOL needRestoreFromDyldImages = dyldImagesInfoFile.length > 0;
#endif
    if (needRestoreFromDyldImages)
        mtha_start_dyld_restore(dyldImagesInfoFile);

    do {
        NSMutableDictionary *category = [NSMutableDictionary dictionary];
        category[@"size"] = @(log->size);
        category[@"record_count"] = @(log->count);
        category[@"stack_id_count"] = @(log->stacks->size());

        uint64_t categoryPtr = (uint64_t)log->name;
        char *categoryName = NULL;
        if (needRestoreFromDyldImages) {
            uint64_t restore_addr = mtha_dyld_restore_address(categoryPtr);
            if (restore_addr > 0)
                categoryName = (char *)restore_addr;
        } else if (dyldImagesInfoFile.length == 0 && mtha_symbol_addr_check_basic((vm_address_t)categoryPtr)) {
            // when run this for current session, we don't need restore images.}
            categoryName = (char *)categoryPtr;
        }

        if (categoryName != NULL && strnlen(categoryName, 10) != 0 && categoryName[0] > '?') {
            category[@"name"] = [NSString stringWithUTF8String:categoryName];
        }

        if (log->size >= thresholdInBytes) {
            NSMutableArray *stackArr = [NSMutableArray array];

            std::list<AllocateRecords::InStackId *> *stacks = log->stacks;
            for (auto sit = stacks->begin(); sit != stacks->end(); ++sit) {
                AllocateRecords::InStackId *stack = *sit;
                if (stack->size < thresholdInBytes)
                    break;

                NSMutableDictionary *stackDict = [NSMutableDictionary dictionary];
                stackDict[@"size"] = @(stack->size);
                stackDict[@"count"] = @(stack->count);

                if (!stackRecords)
                    continue;

                // 获取分配内存时的调用堆栈
                uint32_t frame_count = 0;
                mtha_unwind_stack_from_table_index(stackRecords, stack->stack_id, frames, &frame_count, MTH_ALLOCATIONS_MAX_STACK_SIZE);
                NSMutableArray *frameArr = [NSMutableArray array];
                for (uint32_t i = 0; i < frame_count; i++) {
                    vm_address_t addr = frames[i];
                    [frameArr addObject:[NSString stringWithFormat:@"%p", (void *)addr]];
                }
                stackDict[@"frames"] = frameArr;
                [stackArr addObject:stackDict];
            }
            category[@"stacks"] = stackArr;
        }

        if (log->size >= thresholdInBytes || log->count >= categoryElementCountThreshold) {
            [categories addObject:category];
        }

        log = allocationRecords->nextRecordInCategory();
    } while (log != NULL);

    if (needRestoreFromDyldImages)
        mtha_end_dyld_restore();

    NSDictionary *report = @{
        @"threshold_in_bytes" : @(thresholdInBytes),
        @"total_size" : @(allocationRecords->recordSize()),
        @"allocate_record_count" : @(allocationRecords->allocateRecordCount()),
        @"stack_record_count" : @(allocationRecords->stackRecordCount()),
        @"category_record_count" : @(allocationRecords->categoryRecordCount()),
        @"categories" : categories ?: @[],
    };

    NSError *error = NULL;
    NSData *tmpData = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:&error];
    if (error != NULL) {
        MTHLogWarn(" Allocations flush stacks record to file, json serialize failed: %s", [[error localizedDescription] UTF8String]);
        return;
    }
    NSString *tmpStr = [[NSString alloc] initWithData:tmpData encoding:NSASCIIStringEncoding];
    if (![tmpStr writeToFile:filePath atomically:YES encoding:NSASCIIStringEncoding error:&error]) {
        MTHLogWarn(" Allocations flush stacks record to file failed: %s", [[error localizedDescription] UTF8String]);
    }
}

// MARK: - public

RecordOutput::~RecordOutput() {
}

void RecordOutput::flushReportToConsoleFormatInLine(uint32_t thresholdInBytes) {
    MTHStackFrameSymbolics *helper = new MTHStackFrameSymbolics();
    flush_stack_records_to_console_in_line(_allocationRecords, _stackRecords, helper, thresholdInBytes, _categoryElementCountThreshold);
    delete helper;
}

void RecordOutput::flushReportToFileFormatInLine(uint32_t thresholdInBytes, NSString *filePath) {
    MTHStackFrameSymbolics *helper = new MTHStackFrameSymbolics();
    flush_stack_records_to_file_in_line(_allocationRecords, _stackRecords, helper, thresholdInBytes, _categoryElementCountThreshold, filePath);
    delete helper;
}

void RecordOutput::flushReportToFileFormatInJson(uint32_t thresholdInBytes, NSString *reportFilePath, NSString *dyldImagesInfoFile) {
    flush_stack_records_to_file_in_json(_allocationRecords, _stackRecords, thresholdInBytes, _categoryElementCountThreshold, reportFilePath, dyldImagesInfoFile);
}

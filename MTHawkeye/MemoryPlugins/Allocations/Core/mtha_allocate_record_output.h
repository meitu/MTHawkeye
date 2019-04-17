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


#ifndef mtha_report_output_h
#define mtha_report_output_h

#include <stdio.h>
#include "mtha_allocate_record_reader.h"

#import <Foundation/Foundation.h>

namespace MTHAllocation {

class RecordOutput
{
  public:
    RecordOutput(AllocateRecords &allocateRecords, mtha_backtrace_uniquing_table *stackRecords, uint32_t categoryElementCountThreshold = 0)
        : _stackRecords(stackRecords)
        , _categoryElementCountThreshold(categoryElementCountThreshold) {
        _allocationRecords = &allocateRecords;
    };

    ~RecordOutput();

    void flushReportToConsoleFormatInLine(uint32_t thresholdInBytes);
    void flushReportToFileFormatInLine(uint32_t thresholdInBytes, NSString *filePath);

    /**
     @param dyldImagesInfoFile Only need for history session report.
     */
    void flushReportToFileFormatInJson(uint32_t thresholdInBytes, NSString *reportFilePath, NSString *dyldImagesInfoFile);

  private:
    AllocateRecords *_allocationRecords = NULL;
    mtha_backtrace_uniquing_table *_stackRecords = NULL;

    uint32_t _categoryElementCountThreshold = 0; /**< only when the category element count exceed the limit, output to report */

  private:
    RecordOutput(const RecordOutput &);
    RecordOutput &operator=(const RecordOutput &);
};

}

#endif /* mtha_report_output_h */

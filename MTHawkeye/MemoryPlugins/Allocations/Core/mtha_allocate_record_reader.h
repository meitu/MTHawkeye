//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/7/27
// Created by: EuanC
//


#ifndef mtha_record_reader_h
#define mtha_record_reader_h

#include <list>
#include <mach/mach.h>
#include <stdio.h>
#include <vector>

#include "mtha_allocate_logging.h"

namespace MTHAllocation {

class AllocateRecords
{
  public:
    /**
         Group allocation records by backtrace (stack_id)
         */
    typedef struct {
        uint32_t size;     /**< total size of memory allocate by this backtrace (stack_id) */
        uint32_t count;    /**< total count of memory pointers allocate by this backtrace (stack_id) */
        uint64_t stack_id; /**< backtrace identify, refer to backtrace_uniquing_table */
    } InStackId;

    /**
         Group allocation records by category
         */
    typedef struct {
        const char *name;               /**< category name */
        uint32_t size;                  /**< total size of memory allocate under this category */
        uint32_t count;                 /**< total count of memory pointers allocate under this category */
        std::list<InStackId *> *stacks; /**< all the stacks that allocate memory under this category */
    } InCategory;

  public:
    AllocateRecords(mtha_splay_tree *rawRecords)
        : _rawRecords(rawRecords) {}
    ~AllocateRecords();

    /**
     Read the raw records and group it by Category & StackId
     */
    void parseAndGroupingRawRecords(void);

    InCategory *firstRecordInCategory(void);
    InCategory *nextRecordInCategory(void);
    void resetInCategoryIterator(void);

    uint64_t recordSize() const;
    uint32_t allocateRecordCount() const;
    uint32_t stackRecordCount() const;
    uint32_t categoryRecordCount() const;

  private:
    void freeFormedRecords(void);

    mtha_splay_tree *_rawRecords = NULL;
    std::list<InCategory *> *_formedRecords = NULL;

    uint64_t _recordSize = 0;
    uint32_t _allocateRecordCount = 0;
    uint32_t _stackRecordCount = 0;
    uint32_t _categoryRecordCount = 0;

    const std::list<InCategory *>::const_iterator kNullIterator;
    std::list<InCategory *>::const_iterator _recordIterator = kNullIterator;

  private:
    AllocateRecords(const AllocateRecords &);
    AllocateRecords &operator=(const AllocateRecords &);
};

} // namespace MTHAllocation

#endif /* mtha_record_reader_h */

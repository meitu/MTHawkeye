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


#ifndef mtha_inner_allocate_h
#define mtha_inner_allocate_h

#include <malloc/malloc.h>
#include <stdio.h>
#include <sys/types.h>

#define VM_AMKE_TAG_HAWKEYE_UNIQUING_TABLE 200 //

#ifdef __cplusplus
extern "C" {
#endif

void mtha_setup_hawkeye_malloc_zone(malloc_zone_t *zone);

void *mtha_allocate_page(uint64_t memSize);
int mtha_deallocate_pages(void *memPointer, uint64_t memSize);

void *mtha_malloc(size_t size);
void *mtha_realloc(void *ptr, size_t size);
void mtha_free(void *ptr);

#ifdef __cplusplus
}
#endif

#endif /* mtha_inner_allocate_h */

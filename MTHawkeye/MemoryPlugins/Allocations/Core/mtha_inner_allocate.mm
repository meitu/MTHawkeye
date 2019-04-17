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


#include "mtha_inner_allocate.h"
#include <mach/mach.h>

static malloc_zone_t *mem_zone = nullptr;

void mtha_setup_hawkeye_malloc_zone(malloc_zone_t *zone) {
    mem_zone = zone;
}

void *mtha_allocate_page(uint64_t memSize) {
    vm_address_t allocatedMem = 0ull;
    if (vm_allocate(mach_task_self(), &allocatedMem, (vm_size_t)memSize, VM_FLAGS_ANYWHERE | VM_MAKE_TAG(VM_AMKE_TAG_HAWKEYE_UNIQUING_TABLE)) != KERN_SUCCESS) {
        malloc_printf("[hawkeye][error] allocate_pages(): virtual memory exhausted!\n");
    }
    return (void *)(uintptr_t)allocatedMem;
}

int mtha_deallocate_pages(void *memPointer, uint64_t memSize) {
    return vm_deallocate(mach_task_self(), (vm_address_t)(uintptr_t)memPointer, (vm_size_t)memSize);
}

void *mtha_malloc(size_t size) {
    return mem_zone->malloc(mem_zone, size);
}

void *mtha_realloc(void *ptr, size_t size) {
    return mem_zone->realloc(mem_zone, ptr, size);
}

void mtha_free(void *ptr) {
    mem_zone->free(mem_zone, ptr);
}

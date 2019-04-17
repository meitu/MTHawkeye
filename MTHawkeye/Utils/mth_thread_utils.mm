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


#include "mth_thread_utils.h"

#include <mach/mach_init.h>
#include <mach/mach_port.h>
#include <mach/mach_types.h>
#include <mach/task.h>
#include <mach/thread_act.h>
#include <mach/vm_map.h>
#include <malloc/malloc.h>

static thread_act_array_t thread_list;
static mach_msg_type_number_t thread_count;

bool mth_suspend_all_child_threads(void) {
    kern_return_t ret = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (ret != KERN_SUCCESS)
        return false;

    for (mach_msg_type_number_t i = 0; i < thread_count; i++) {
        thread_t thread = thread_list[i];
        if (thread == mach_thread_self()) {
            continue;
        }
        if (KERN_SUCCESS != thread_suspend(thread)) {
            for (mach_msg_type_number_t j = 0; j < i; j++) {
                thread_t pre_thread = thread_list[j];
                if (pre_thread == mach_thread_self()) {
                    continue;
                }
                thread_resume(pre_thread);
            }
            for (mach_msg_type_number_t i = 0; i < thread_count; i++) {
                mach_port_deallocate(mach_task_self(), thread_list[i]);
            }
            vm_deallocate(mach_task_self(), (vm_address_t)thread_list, thread_count * sizeof(thread_t));
            return false;
        }
    }
    return true;
}

bool mth_resume_all_child_threads(void) {
    for (mach_msg_type_number_t i = 0; i < thread_count; i++) {
        thread_t thread = thread_list[i];
        if (thread == mach_thread_self()) {
            continue;
        }
        if (thread_resume(thread) != KERN_SUCCESS) {
            malloc_printf("[hawkeye][error] can't resume thread:%u\n", thread);
        }
    }
    for (mach_msg_type_number_t i = 0; i < thread_count; i++) {
        mach_port_deallocate(mach_task_self(), thread_list[i]);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)thread_list, thread_count * sizeof(thread_t));
    thread_list = NULL;
    thread_count = 0;
    return true;
}

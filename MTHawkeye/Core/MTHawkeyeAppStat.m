//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/10
// Created by: EuanC
//


#import "MTHawkeyeAppStat.h"
#import <mach/mach.h>
#import <mach/mach_types.h>
#import <pthread.h>


@implementation MTHawkeyeAppStat

+ (int64_t)memoryAppUsed {
    struct task_basic_info info;
    mach_msg_type_number_t size = (sizeof(task_basic_info_data_t) / sizeof(natural_t));
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    if (kerr == KERN_SUCCESS) {
        return info.resident_size;
    } else {
        return 0;
    }
}

+ (int64_t)memoryFootprint {
    task_vm_info_data_t vmInfo;
    vmInfo.phys_footprint = 0;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t result = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&vmInfo, &count);
    if (result != KERN_SUCCESS)
        return 0;

    return vmInfo.phys_footprint;
}

+ (double)cpuUsedByAllThreads {
    double totalUsageRatio = 0;
    double maxRatio = 0;

    thread_info_data_t thinfo;
    thread_act_array_t threads;
    thread_basic_info_t basic_info_t;
    mach_msg_type_number_t count = 0;
    mach_msg_type_number_t thread_info_count = THREAD_INFO_MAX;

    if (task_threads(mach_task_self(), &threads, &count) == KERN_SUCCESS) {
        for (int idx = 0; idx < count; idx++) {
            if (thread_info(threads[idx], THREAD_BASIC_INFO, (thread_info_t)thinfo, &thread_info_count) == KERN_SUCCESS) {
                basic_info_t = (thread_basic_info_t)thinfo;

                if (!(basic_info_t->flags & TH_FLAGS_IDLE)) {
                    double cpuUsage = basic_info_t->cpu_usage / (double)TH_USAGE_SCALE;
                    if (cpuUsage > maxRatio) {
                        maxRatio = cpuUsage;
                    }
                    totalUsageRatio += cpuUsage;
                }
            }
        }

        assert(vm_deallocate(mach_task_self(), (vm_address_t)threads, count * sizeof(thread_t)) == KERN_SUCCESS);
    }
    return totalUsageRatio;
}

@end

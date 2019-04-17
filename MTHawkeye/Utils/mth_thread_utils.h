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


#ifndef mth_thread_utils_h
#define mth_thread_utils_h

#include <stdbool.h>
#include <stdio.h>


#ifdef __cplusplus
extern "C" {
#endif // __cplusplus


bool mth_suspend_all_child_threads(void);
bool mth_resume_all_child_threads(void);


#ifdef __cplusplus
}
#endif // __cplusplus


#endif /* mth_thread_utils_h */

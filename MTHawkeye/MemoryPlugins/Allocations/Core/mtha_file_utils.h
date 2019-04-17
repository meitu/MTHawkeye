//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/10/25
// Created by: EuanC
//


#ifndef mtha_file_utils_h
#define mtha_file_utils_h

#import <stdbool.h>
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

bool mtha_is_file_exist(const char *filepath);

bool mtha_create_file(const char *filepath);

size_t mtha_get_file_size(int fd);

#ifdef __cplusplus
}
#endif

#endif /* mtha_file_utils_h */

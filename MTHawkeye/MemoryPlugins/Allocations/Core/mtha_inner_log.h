//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/11/26
// Created by: EuanC
//


#ifndef mtha_inner_log_h
#define mtha_inner_log_h


#ifdef __has_include

#if __has_include("MTHawkeyeLogMacros.h")

#include "MTHawkeyeLogMacros.h"

#else

#define MTHLog(fmt, ...) NSLog((@"%s " fmt), ##__VA_ARGS__)
#define MTHLogInfo(fmt, ...) NSLog((@"[Info] " fmt), ##__VA_ARGS__)
#define MTHLogWarn(fmt, ...) NSLog((@"[Warn] " fmt), ##__VA_ARGS__)
#define MTHLogError(fmt, ...) NSLog((@"[Error] " fmt), ##__VA_ARGS__)

#endif

#endif // __has_include


#endif /* mtha_inner_log_h */

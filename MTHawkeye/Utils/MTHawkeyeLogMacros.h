//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/6/14
// Created by: EuanC
//


#pragma once

#ifndef MTHAWKEYE_LOG_MACROS_H
#define MTHAWKEYE_LOG_MACROS_H

#import "MTHawkeyeInnerLogger.h"

// clang-format off

#ifdef DEBUG

#if __has_include(<CocoaLumberjack/CocoaLumberjack.h>)

#import <CocoaLumberjack/CocoaLumberjack.h>

static DDLogLevel ddLogLevel = DDLogLevelVerbose;
static DDLog *mthawkeye_ddlog = nil;

/**
 * These are the two macros that all other macros below compile into.
 * These big multiline macros makes all the other macros easier to read.
 **/
#define MTH_LOG_MACRO(isAsynchronous, lvl, flg, ctx, atag, frmt, ...)       \
                      [MTHawkeyeInnerLogger log : isAsynchronous            \
                                          level : lvl                       \
                                           flag : flg                       \
                                            tag : atag                      \
                                         format : (frmt), ## __VA_ARGS__]

#define MTH_LOG_MAYBE(async, lvl, flg, tag, frmt, ...) \
        do { if(lvl & flg) MTH_LOG_MACRO(async, lvl, flg, tag, frmt, ##__VA_ARGS__); } while(0)

#define MTHLog(fmt, ...) MTH_LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagVerbose, 0, nil, fmt, ##__VA_ARGS__)
#define MTHLogDebug(fmt, ...) MTH_LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagDebug, 0, nil, (@"[Debug] " fmt), ##__VA_ARGS__)
#define MTHLogInfo(fmt, ...) MTH_LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagInfo, 0, nil, (@"[Info] " fmt), ##__VA_ARGS__)
#define MTHLogWarn(fmt, ...) MTH_LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagWarning, 0, nil, (@"[Warn] " fmt), ##__VA_ARGS__)
#define MTHLogError(fmt, ...) MTH_LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagError, 0, nil, (@"[Error] " fmt), ##__VA_ARGS__)

#else

#define MTHLog(fmt, ...) NSLog((@"%s " fmt), ##__VA_ARGS__)
#define MTHLogDebug(fmt, ...) NSLog((@"[Debug] " fmt), ##__VA_ARGS__)
#define MTHLogInfo(fmt, ...) NSLog((@"[Info] " fmt), ##__VA_ARGS__)
#define MTHLogWarn(fmt, ...) NSLog((@"[Warn] " fmt), ##__VA_ARGS__)
#define MTHLogError(fmt, ...) NSLog((@"[Error] " fmt), ##__VA_ARGS__)

#endif /* __has_include(<CocoaLumberjack/CocoaLumberjack.h>) */

#else // !DEBUG

#if __has_include(<CocoaLumberjack/CocoaLumberjack.h>)

#import <CocoaLumberjack/CocoaLumberjack.h>

static DDLogLevel ddLogLevel = DDLogLevelVerbose;

#define MTH_LOG_MACRO(isAsynchronous, lvl, flg, ctx, atag, frmt, ...)       \
                      [MTHawkeyeInnerLogger log : isAsynchronous            \
                                          level : lvl                       \
                                           flag : flg                       \
                                            tag : atag                      \
                                         format : (frmt), ## __VA_ARGS__]

#define MTH_LOG_MAYBE(async, lvl, flg, tag, frmt, ...) \
        do { if(lvl & flg) MTH_LOG_MACRO(async, lvl, flg, tag, frmt, ##__VA_ARGS__); } while(0)

#define MTHLog(fmt, ...) MTH_LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagVerbose, 0, nil, fmt, ##__VA_ARGS__)
#define MTHLogDebug(fmt, ...) MTH_LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagDebug, 0, nil, (@"[Debug] " fmt), ##__VA_ARGS__)
#define MTHLogInfo(fmt, ...) MTH_LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagInfo, 0, nil, (@"[Info] " fmt), ##__VA_ARGS__)
#define MTHLogWarn(fmt, ...) MTH_LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagWarning, 0, nil, (@"[Warn] " fmt), ##__VA_ARGS__)
#define MTHLogError(fmt, ...) MTH_LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagError, 0, nil, (@"[Error] " fmt), ##__VA_ARGS__)

#else

#define MTHLog(fmt, ...)
#define MTHLogDebug(fmt, ...)
#define MTHLogInfo(fmt, ...)
#define MTHLogWarn(fmt, ...)
#define MTHLogError(fmt, ...)

#endif /* __has_include(<CocoaLumberjack/CocoaLumberjack.h>) */

#endif // DEBUG


// clang-format on

#endif // MTHAWKEYE_LOG_MACROS_H

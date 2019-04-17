//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/28
// Created by: EuanC
//


#ifndef MTHawkeyeSignPosts_h
#define MTHawkeyeSignPosts_h

typedef NS_ENUM(uintptr_t, MTHSignpostColor) {
    MTHSignpostColorBlue,
    MTHSignpostColorGreen,
    MTHSignpostColorPurple,
    MTHSignpostColorOrange,
    MTHSignpostColorRed,
    MTHSignpostColorDefault
};

// clang-format off
#ifndef kCFCoreFoundationVersionNumber_iOS_10_0
    #define kCFCoreFoundationVersionNumber_iOS_10_0 1348.00
#endif

#define MTH_AT_LEAST_IOS10  (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_10_0)


#ifdef MTH_PROFILE
    #if __has_include(<sys/kdebug_signpost.h>)
        #define MTH_KDEBUG_ENABLE 1
    #else
        #define MTH_KDEBUG_ENABLE 0
    #endif
#else
    #define MTH_KDEBUG_ENABLE 0
#endif

#if MTH_KDEBUG_ENABLE

#import <sys/kdebug_signpost.h>

// These definitions are required to build the backward-compatible kdebug trace
// on the iOS 10 SDK.  The kdebug_trace function crashes if run on iOS 9 and earlier.
// It's valuable to support trace signposts on iOS 9, because A5 devices don't support iOS 10.
#ifndef DBG_MACH_CHUD
    #define DBG_MACH_CHUD 0x0A
    #define DBG_FUNC_NONE 0
    #define DBG_FUNC_START 1
    #define DBG_FUNC_END 2
    #define DBG_APPS 33
    #define SYS_kdebug_trace 180
    #define KDBG_CODE(Class, SubClass, code) (((Class & 0xff) << 24) | ((SubClass & 0xff) << 16) | ((code & 0x3fff) << 2))
    #define APPSDBG_CODE(SubClass, code) KDBG_CODE(DBG_APPS, SubClass, code)
#endif

// Currently we'll reserve arg3.
#define MTHSignpost(name, identifier, arg2, color) \
    MTH_AT_LEAST_IOS10 ? kdebug_signpost(name, (uintptr_t)identifier, (uintptr_t)arg2, 0, color) \
                       : syscall(SYS_kdebug_trace, APPSDBG_CODE(DBG_MACH_CHUD, name) | DBG_FUNC_NONE, (uintptr_t)identifier, (uintptr_t)arg2, 0, color);

#define MTHSignpostStartCustom(name, identifier, arg2) \
    MTH_AT_LEAST_IOS10 ? kdebug_signpost_start(name, (uintptr_t)identifier, (uintptr_t)arg2, 0, 0) \
                       : syscall(SYS_kdebug_trace, APPSDBG_CODE(DBG_MACH_CHUD, name) | DBG_FUNC_START, (uintptr_t)identifier, (uintptr_t)arg2, 0, 0);

#define MTHSignpostStart(name) MTHSignpostStartCustom(name, self, 0)

#define MTHSignpostEndCustom(name, identifier, arg2, color) \
    MTH_AT_LEAST_IOS10 ? kdebug_signpost_end(name, (uintptr_t)identifier, (uintptr_t)arg2, 0, color) \
                       : syscall(SYS_kdebug_trace, APPSDBG_CODE(DBG_MACH_CHUD, name) | DBG_FUNC_END, (uintptr_t)identifier, (uintptr_t)arg2, 0, color);

#define MTHSignpostEnd(name) MTHSignpostEndCustom(name, self, 0, MTHSignpostColorDefault)

#else // !MTH_KDEBUG_ENABLE

#define MTHSignpost(name, identifier, arg2, color)
#define MTHSignpostStartCustom(name, identifier, arg2)
#define MTHSignpostStart(name)
#define MTHSignpostEndCustom(name, identifier, arg2, color)
#define MTHSignpostEnd(name)

#endif // MTH_KDEBUG_ENABLE

// clang-format on

#endif /* MTHawkeyeSignPosts_h */

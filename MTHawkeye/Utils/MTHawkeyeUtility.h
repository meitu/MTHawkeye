//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 4/18/18
// Created by: EuanC
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef enum : NSUInteger {
    MTHawkeyeStoreDirectoryOptionDocument,      /**< Document/ */
    MTHawkeyeStoreDirectoryOptionLibraryCaches, /**< Library/Caches */
    MTHawkeyeStoreDirectoryOptionTmp,           /**< tmp/ */
} MTHawkeyeStoreDirectoryOption;

// clang-format off
#ifndef MTHawkeye_Store_Under_LibraryCache
#  define MTHawkeye_Store_Under_LibraryCache 0
#endif

#ifndef MTHawkeye_Store_Under_Tmp
#  define MTHawkeye_Store_Under_Tmp 0
#endif
// clang-format on

/*
 default Document/
 define MACRO `MTHawkeye_Store_Under_LibraryCache 1` to use `Library/Cache`
 define MACRO `MTHawkeye_Store_Under_Tmp 1` to use `tmp`
 */
extern MTHawkeyeStoreDirectoryOption gMTHawkeyeStoreDirectoryRoot; /**< default MTHawkeyeStoreDirectoryOptionDocument */

@interface MTHawkeyeUtility : NSObject

+ (BOOL)underUnitTest;

+ (double)currentTime;
+ (NSTimeInterval)appLaunchedTime;

+ (NSString *)hawkeyeStoreDirectory;           /**< Hawkeye Cache Files Root: default /Document/com.meitu.hawkeye/, see gMTHawkeyeStoreDirectoryRoot for detail */
+ (NSString *)currentStoreDirectoryNameFormat; /**< yyyy-MM-dd_HH:mm:ss+SSS */
+ (NSString *)currentStorePath;                /**< Current Session Hawkeye cache directory, default /Document/com.meitu.hawkeye/yyyy-MM-dd_HH:mm:ss+SSS */
+ (NSString *)previousSessionStorePath;        /**< Previous session Hawkeye cache directory, find by convert directory name into time in desc order. */

@end

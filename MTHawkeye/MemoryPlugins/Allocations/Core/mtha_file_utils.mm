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


#include "mtha_file_utils.h"
#include <Foundation/Foundation.h>

#include <string.h>
#include <sys/stat.h>

#include "mtha_inner_log.h"


bool mtha_is_file_exist(const char *filepath) {
    if (strnlen(filepath, PATH_MAX) == 0) {
        return false;
    }

    struct stat temp;
    return lstat(filepath, &temp) == 0;
}

bool mtha_create_file(const char *filepath) {
    NSString *nsFilePath = [NSString stringWithUTF8String:filepath];
    NSFileManager *oFileMgr = [NSFileManager defaultManager];
    // try create file at once
    NSMutableDictionary *fileAttr = [NSMutableDictionary dictionary];
#if TARGET_OS_IOS || TARGET_OS_WATCH || TARGET_OS_TV
    [fileAttr setObject:NSFileProtectionCompleteUntilFirstUserAuthentication
                 forKey:NSFileProtectionKey];
#endif
    if ([oFileMgr createFileAtPath:nsFilePath contents:nil attributes:fileAttr]) {
        return true;
    }

    // create parent directories
    NSString *nsPath = [nsFilePath stringByDeletingLastPathComponent];

    //path is not nullptr && is not '/'
    NSError *err;
    if ([nsPath length] > 1 && ![oFileMgr createDirectoryAtPath:nsPath withIntermediateDirectories:YES attributes:nil error:&err]) {
        MTHLogWarn(@"create file path:%s fail:%s.", [nsPath UTF8String], [[err localizedDescription] UTF8String]);
        return false;
    }
    // create file again
    if (![oFileMgr createFileAtPath:nsFilePath contents:nil attributes:fileAttr]) {
        MTHLogWarn(@"create file path:%s fail.", [nsFilePath UTF8String]);
        return false;
    }
    return true;
}

size_t mtha_get_file_size(int fd) {
    struct stat st = {};
    if (fstat(fd, &st) == -1)
        return 0;

    return (size_t)st.st_size;
}

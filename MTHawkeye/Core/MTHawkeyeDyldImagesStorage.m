//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/1
// Created by: EuanC
//


#import "MTHawkeyeDyldImagesStorage.h"
#import "MTHawkeyeStorage.h"

#import <MTHawkeye/MTHawkeyeDyldImagesUtils.h>
#import <MTHawkeye/MTHawkeyeLogMacros.h>

@implementation MTHawkeyeDyldImagesStorage

+ (void)asyncCacheDyldImagesInfoIfNeeded {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path = [self storagePath];
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            mtha_setup_dyld_images_dumper_with_path(path);
        }
    });
}

+ (NSDictionary *)cachedDyldImagesInfo {
    NSString *dyldImagesInfoString = [[NSString alloc] initWithContentsOfFile:[self storagePath] encoding:NSUTF8StringEncoding error:nil];
    NSData *dyldImagesInfoData = [dyldImagesInfoString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dyldImagesDict = nil;
    if (dyldImagesInfoData) {
        NSError *error;
        dyldImagesDict = [NSJSONSerialization JSONObjectWithData:dyldImagesInfoData options:0 error:&error];
        if (error || ![dyldImagesDict isKindOfClass:[NSDictionary class]]) {
            NSString *errMsg = [NSString stringWithFormat:@"convert dyld images file string to json failed: %@", error];
            MTHLogWarn(@"%@", errMsg);
        }
    }
    return dyldImagesDict;
}

+ (NSString *)storagePath {
    NSString *path = [[[MTHawkeyeStorage shared] storeDirectory] stringByAppendingPathComponent:@"dyld-images"];
    return path;
}

@end

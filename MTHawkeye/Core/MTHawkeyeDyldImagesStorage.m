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
#import "MTHawkeyeUtility.h"

#import <MTHawkeye/MTHawkeyeDyldImagesUtils.h>
#import <MTHawkeye/MTHawkeyeLogMacros.h>

@implementation MTHawkeyeDyldImagesStorage

+ (void)asyncCacheDyldImagesInfoIfNeeded {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path = [self currentStoragePath];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
                mtha_setup_dyld_images_dumper_with_path(path);
            }
        });
    });
}

+ (NSDictionary *)cachedDyldImagesInfo {
    return [self cachedDyldImagesInfoAt:[self currentStoragePath]];
}

+ (NSDictionary *)previousSessionCachedDyldImagesInfo {
    NSString *prevSessionPath = [MTHawkeyeUtility previousSessionStorePath];
    if (prevSessionPath.length == 0) return nil;
    return [self cachedDyldImagesInfoAt:[prevSessionPath stringByAppendingPathComponent:@"dyld-images"]];
}

+ (NSDictionary *)cachedDyldImagesInfoAt:(NSString *)dyldImagesCacheFilePath {
    NSString *dyldImagesInfoString = [[NSString alloc] initWithContentsOfFile:dyldImagesCacheFilePath encoding:NSUTF8StringEncoding error:nil];
    NSData *dyldImagesInfoData = [dyldImagesInfoString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dyldImagesDict = nil;
    if (dyldImagesInfoData) {
        NSError *error;
        dyldImagesDict = [NSJSONSerialization JSONObjectWithData:dyldImagesInfoData options:0 error:&error];
        if (error || ![dyldImagesDict isKindOfClass:[NSDictionary class]]) {
            MTHLogWarn(@"%@", [NSString stringWithFormat:@"convert dyld images file string to json failed: %@, at:%@", error, dyldImagesCacheFilePath]);
        }
    }
    return dyldImagesDict;
}

+ (NSString *)currentStoragePath {
    NSString *path = [[MTHawkeyeUtility currentStorePath] stringByAppendingPathComponent:@"dyld-images"];
    return path;
}

@end

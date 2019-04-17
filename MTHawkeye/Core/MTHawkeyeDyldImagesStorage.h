//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2019/4/1
// Created by: EuanC
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTHawkeyeDyldImagesStorage : NSObject

+ (void)asyncCacheDyldImagesInfoIfNeeded;

+ (NSDictionary *)cachedDyldImagesInfo;

@end

NS_ASSUME_NONNULL_END

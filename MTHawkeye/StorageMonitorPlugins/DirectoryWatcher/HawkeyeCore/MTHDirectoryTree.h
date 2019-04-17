//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/121/14
// Created by: David.Dai
//


#import <Foundation/Foundation.h>

#define MTHDirectoryTreeDocument @"Documents"
#define MTHDirectoryTreeCaches @"Library/Caches"
#define MTHDirectoryTreePreferences @"Library/Preferences"
#define MTHDirectoryTreeTmp @"tmp"

NS_ASSUME_NONNULL_BEGIN

@interface MTHDirectoryTree : NSObject
@property (nonatomic, copy, readonly) NSString *relativePath;
@property (nonatomic, copy, readonly) NSString *absolutePath;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSArray<MTHDirectoryTree *> *childTree;

- (instancetype)initWithRelativePath:(NSString *)path;
@end

NS_ASSUME_NONNULL_END

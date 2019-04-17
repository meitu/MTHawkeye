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


#import "MTHDirectoryTree.h"

@interface MTHDirectoryTree ()
@property (nonatomic, copy) NSString *relativePath;
@property (nonatomic, copy) NSString *absolutePath;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSArray<NSString *> *childDirPath;
@property (nonatomic, copy) NSArray<MTHDirectoryTree *> *childTree;
@end

@implementation MTHDirectoryTree

- (instancetype)initWithRelativePath:(NSString *)path {
    if (self = [super init]) {
        _relativePath = path ? path : @"";
    }
    return self;
}

- (NSString *)absolutePath {
    if (!_absolutePath) {
        _absolutePath = [NSHomeDirectory() stringByAppendingPathComponent:_relativePath];
    }
    return _absolutePath;
}

- (NSString *)name {
    if (!_name) {
        _name = [_relativePath lastPathComponent];
    }
    return _name;
}

- (NSArray<NSString *> *)childDirPath {
    if (!_childDirPath) {
        NSArray<NSString *> *childItem = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.absolutePath error:nil];
        NSMutableArray *childDir = [NSMutableArray array];
        for (NSString *childName in childItem) {
            NSString *childAbsolutePath = [self.absolutePath stringByAppendingPathComponent:childName];
            BOOL isDir = NO;
            [[NSFileManager defaultManager] fileExistsAtPath:childAbsolutePath isDirectory:&isDir];
            if (isDir) {
                [childDir addObject:[self.relativePath stringByAppendingPathComponent:childName]];
            }
        }
        _childDirPath = childDir;
    }
    return _childDirPath;
}

- (NSArray<MTHDirectoryTree *> *)childTree {
    if (!_childTree) {
        NSMutableArray *childTree = [NSMutableArray array];
        for (NSString *path in self.childDirPath) {
            [childTree addObject:[[MTHDirectoryTree alloc] initWithRelativePath:path]];
        }
        _childTree = childTree;
    }
    return _childTree;
}
@end

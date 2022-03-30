//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/16
// Created by: EuanC
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^MTHawkeyeUserDefaultChangedHandler)(_Nullable id oldValue, _Nullable id newValue);

@interface MTHawkeyeUserDefaults : NSObject

@property (nonatomic, assign) BOOL hawkeyeOn;

@property (nonatomic, assign) NSTimeInterval statusFlushIntevalInSeconds;
@property (nonatomic, assign) BOOL statusFlushKeepRedundantRecords; // only record when status changed.

@property (nonatomic, assign) BOOL recordMemoryUsage;
@property (nonatomic, assign) BOOL recordAvlMemory; // iOS 13+
@property (nonatomic, assign) BOOL recordCPUUsage;

+ (instancetype)shared;

- (void)mth_addObserver:(nullable NSObject *)object forKey:(NSString *)key withHandler:(MTHawkeyeUserDefaultChangedHandler)handler;
- (void)mth_removeObserver:(NSObject *)observer forKey:(NSString *)key;

- (nullable id)objectForKey:(NSString *)defaultName;
- (void)setObject:(nullable id)value forKey:(NSString *)defaultName;

@end

NS_ASSUME_NONNULL_END

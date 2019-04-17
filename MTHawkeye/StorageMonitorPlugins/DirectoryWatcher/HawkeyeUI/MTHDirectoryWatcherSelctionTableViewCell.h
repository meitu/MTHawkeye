//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/121/18
// Created by: David.Dai
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTHDirectoryWatcherSelctionTableViewCell : UITableViewCell
@property (nonatomic, assign) BOOL isWatching;
@property (nonatomic, strong) NSString *path;
@property (nonatomic, assign) BOOL haveChild;
@property (nonatomic, copy) dispatch_block_t switchBlock;
@end

NS_ASSUME_NONNULL_END

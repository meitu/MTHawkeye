//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 20/08/2018
// Created by: Huni
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kMTHawkeyeWebTableViewCellIdentifier;

@interface MTHWebTableViewCell : UITableViewCell

- (void)webViewLoadString:(NSString *)string;

@end

NS_ASSUME_NONNULL_END

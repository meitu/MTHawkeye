//
// Copyright (c) 2014-2016, Flipboard
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2/13/15
// Created by: Ryan Olson
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kMTHawkeyeMultilineTableViewCellIdentifier;

@interface MTHMultilineTableViewCell : UITableViewCell

+ (CGFloat)preferredHeightWithAttributedText:(NSAttributedString *)attributedText inTableViewWidth:(CGFloat)tableViewWidth style:(UITableViewStyle)style showsAccessory:(BOOL)showsAccessory;

@end

NS_ASSUME_NONNULL_END

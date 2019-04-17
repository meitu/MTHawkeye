//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/7/3
// Created by: 潘名扬
//


#import "MTHTimeIntervalStepsViewCell.h"
#import <MTHawkeye/MTHUISkeletonUtility.h>


@implementation MTHTimeIntervalStepsViewCellModel
@end

#pragma mark -

@interface MTHTimeIntervalStepsViewCell ()

@property (nonatomic, strong) UIView *decoratedView;

@end

@implementation MTHTimeIntervalStepsViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.textLabel.font = [MTHUISkeletonUtility codeFontWithSize:11];
        self.detailTextLabel.font = [MTHUISkeletonUtility codeFontWithSize:9];
        UIView *decoratedView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 4, 36)];
        decoratedView.backgroundColor = [UIColor greenColor];
        [self.contentView addSubview:decoratedView];
        self.decoratedView = decoratedView;
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    UIColor *color = self.decoratedView.backgroundColor;
    [super setSelected:selected animated:animated];

    if (selected) {
        self.decoratedView.backgroundColor = color;
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    UIColor *color = self.decoratedView.backgroundColor;
    [super setHighlighted:highlighted animated:animated];

    if (highlighted) {
        self.decoratedView.backgroundColor = color;
    }
}

@end

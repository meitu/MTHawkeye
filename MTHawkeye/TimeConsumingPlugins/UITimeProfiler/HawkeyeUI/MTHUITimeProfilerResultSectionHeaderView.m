//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/6/19
// Created by: 潘名扬
//


#import "MTHUITimeProfilerResultSectionHeaderView.h"

static CGFloat const kTopLabelFontSize = 15.f;
static CGFloat const kBottomLabelFontSize = 14.f;
static CGFloat const kLabelLeftMargin = 10.f;
static CGFloat const kHeaderHeight = 40.f;
static CGFloat const kDecoratedLineWidth = 4.f;

@interface MTHUITimeProfilerResultSectionHeaderView ()

@property (nonatomic, strong) UIButton *showDetailButton;

@end

@implementation MTHUITimeProfilerResultSectionHeaderView

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if (self) {
        self.topLabel = [[UILabel alloc] init];
        self.bottomLabel = [[UILabel alloc] init];
        self.showDetailButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
        UIView *decoratedView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kDecoratedLineWidth, kHeaderHeight)];
        UIView *topSeperatorView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1000, 0.5)];

        [self addSubview:self.topLabel];
        [self addSubview:self.bottomLabel];
        [self addSubview:self.showDetailButton];
        [self addSubview:decoratedView];
        [self addSubview:topSeperatorView];

        self.topLabel.textColor = [UIColor colorWithRed:0.788 green:0.569 blue:0.192 alpha:1];
        self.topLabel.font = [UIFont systemFontOfSize:kTopLabelFontSize];
        self.bottomLabel.font = [UIFont systemFontOfSize:kBottomLabelFontSize];
        [self.showDetailButton addTarget:self action:@selector(didClickDetailButton:) forControlEvents:UIControlEventTouchUpInside];
        decoratedView.backgroundColor = [UIColor greenColor];
        topSeperatorView.backgroundColor = [UIColor lightGrayColor];
    }
    return self;
}

- (void)setupWithTopText:(NSString *)topText bottomText:(NSString *)bottomText showDetailBlock:(MTHCallTraceShowDetailBlock)block {
    self.topLabel.text = topText;
    self.bottomLabel.text = bottomText;
    self.showDetailBlock = block;
    self.showDetailButton.hidden = (block == nil);
}

- (void)layoutSubviews {
    [self.topLabel sizeToFit];
    [self.bottomLabel sizeToFit];
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGSize topLabelSize = self.topLabel.frame.size;
    self.topLabel.frame = CGRectMake(kLabelLeftMargin, 2, MIN(topLabelSize.width, screenWidth - kHeaderHeight), topLabelSize.height);
    CGSize bottomLabelSize = self.bottomLabel.frame.size;
    self.bottomLabel.frame = CGRectMake(kLabelLeftMargin, 22, MIN(bottomLabelSize.width, screenWidth - kHeaderHeight), bottomLabelSize.height);
    self.showDetailButton.frame = CGRectMake(screenWidth - kHeaderHeight, 0, kHeaderHeight, kHeaderHeight);
}

- (void)didClickDetailButton:(id)sender {
    if (self.showDetailBlock) {
        self.showDetailBlock();
    }
}

@end

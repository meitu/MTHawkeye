//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 07/11/2017
// Created by: EuanC
//


#import "MTHUITimeProfilerResultCallTraceCell.h"
#import "MTHCallTraceTimeCostModel.h"

#import <MTHawkeye/MTHUISkeletonUtility.h>


static CGFloat kTimeCostLabelFont = 13.f;
static CGFloat kTimeCostLabelHeight = 15.f;
static CGFloat kCallInfoLableFont = 11.f;
static CGFloat kSubCallInfoLabelFont = 11.f;
static CGFloat kSubCallInfoLabelLineHeight = 13.f;
static CGFloat kSubCallInfoLabelLineSpace = 1.5f;

static CGFloat kMarginVert = 7.f;
static CGFloat kMarginHorz = 20.f;


@interface MTHUITimeProfilerResultCallTraceCell ()

@property (nonatomic, strong) MTHCallTraceTimeCostModel *model;
@property (nonatomic, assign) BOOL expanded;

@property (nonatomic, strong) UIScrollView *scrollView;

@end


@implementation MTHUITimeProfilerResultCallTraceCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        [self.contentView addSubview:self.timeCostLabel];

        [self.contentView addSubview:self.scrollView];
        [self.scrollView setUserInteractionEnabled:NO];
        [self.contentView addGestureRecognizer:self.scrollView.panGestureRecognizer];

        [self.scrollView addSubview:self.callInfoLabel];
        [self.scrollView addSubview:self.subCallInfoLabel];
    }
    return self;
}

+ (CGFloat)heightForCallTraceTimeCostModel:(MTHCallTraceTimeCostModel *)model expanded:(BOOL)expanded {
    if (expanded) {
        CGFloat subCallHeight = [self subCallLableHeight:model];
        return 44.f + subCallHeight + kMarginVert;
    } else {
        return 44.f;
    }
}

+ (CGFloat)subCostsCountTotal:(MTHCallTraceTimeCostModel *)model {
    NSInteger count = model.subCosts.count;
    for (MTHCallTraceTimeCostModel *subItem in model.subCosts) {
        count += [self subCostsCountTotal:subItem];
    }
    return count;
}

+ (CGFloat)subCallLableHeight:(MTHCallTraceTimeCostModel *)model {
    NSInteger totalSubCallCount = [self subCostsCountTotal:model];
    CGFloat subCallHeight = totalSubCallCount * kSubCallInfoLabelLineHeight + (totalSubCallCount - 1) * kSubCallInfoLabelLineSpace;
    return subCallHeight;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat left = kMarginHorz;
    CGFloat top = kMarginVert;
    CGFloat subCallTopMargin = kMarginVert;

    self.timeCostLabel.frame = CGRectMake(left, top, 200.f, kTimeCostLabelHeight);

    CGFloat callInfoLabelTop = 24.f;
    CGSize callInfoLabelSize = [self.callInfoLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
    callInfoLabelSize.width += kMarginHorz;
    CGFloat scrollViewContentWidht = callInfoLabelSize.width;
    CGFloat scrollViewContentHeight = callInfoLabelSize.height;

    self.callInfoLabel.frame = CGRectMake(0, 0, callInfoLabelSize.width, callInfoLabelSize.height);

    self.subCallInfoLabel.hidden = !self.expanded;
    if (self.expanded) {
        CGSize subCallInfoLabelSize = [self.subCallInfoLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
        subCallInfoLabelSize.width += kMarginHorz;
        if (subCallInfoLabelSize.width > scrollViewContentWidht) {
            scrollViewContentWidht = subCallInfoLabelSize.width;
        }

        CGFloat subCallTop = CGRectGetMaxY(self.callInfoLabel.frame) + subCallTopMargin;
        CGRect subCallFrame = CGRectMake(0, subCallTop, subCallInfoLabelSize.width, subCallInfoLabelSize.height);
        self.subCallInfoLabel.frame = subCallFrame;

        scrollViewContentHeight += subCallTop + subCallInfoLabelSize.height;
    }

    CGRect scrollViewFrame = CGRectMake(left, callInfoLabelTop, CGRectGetMaxX(self.frame) - left, scrollViewContentHeight);
    self.scrollView.frame = scrollViewFrame;

    CGSize scrollViewContentSize = CGSizeMake(scrollViewContentWidht, CGRectGetHeight(scrollViewFrame));
    self.scrollView.contentSize = scrollViewContentSize;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)configureWithCallTraceTimeCostModel:(MTHCallTraceTimeCostModel *)model expanded:(BOOL)expanded {
    self.model = model;
    self.expanded = expanded;

    self.timeCostLabel.text = [NSString stringWithFormat:@"%.1fms", model.timeCostInMS];

    if (self.model.subCosts.count > 0) {
        if (expanded) {
            self.callInfoLabel.text = [NSString stringWithFormat:@"- [%@ %@]", model.className, model.methodName];
        } else {
            self.callInfoLabel.text = [NSString stringWithFormat:@"+ [%@ %@]", model.className, model.methodName];
        }
        self.subCallInfoLabel.attributedText = [[self class] callTraceSubCostsAttributesString:model];
    } else {
        self.callInfoLabel.text = [NSString stringWithFormat:@"  [%@ %@]", model.className, model.methodName];
        self.subCallInfoLabel.text = nil;
    }

    [self setNeedsLayout];
}

+ (NSAttributedString *)callTraceSubCostsAttributesString:(MTHCallTraceTimeCostModel *)callTraceModel {
    NSMutableAttributedString *mutAttrStr = [[NSMutableAttributedString alloc] init];

    for (MTHCallTraceTimeCostModel *subItem in callTraceModel.subCosts) {
        if (subItem != [callTraceModel.subCosts firstObject]) {
            [mutAttrStr appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
        }
        [mutAttrStr appendAttributedString:[self subCallTraceLineAttributesString:subItem]];
    }

    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    [style setLineSpacing:kSubCallInfoLabelLineSpace];
    [mutAttrStr addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0, [mutAttrStr length])];

    return [mutAttrStr copy];
}

+ (NSAttributedString *)subCallTraceLineAttributesString:(MTHCallTraceTimeCostModel *)subCallTraceModel {
    NSMutableAttributedString *mutAttrStr = [[NSMutableAttributedString alloc] init];
    NSString *timeStr = [NSString stringWithFormat:@"%-6sms", [[NSString stringWithFormat:@"%6.1f", subCallTraceModel.timeCostInMS] UTF8String]];

    NSMutableAttributedString *timeAttrStr = [[NSMutableAttributedString alloc]
        initWithString:timeStr
            attributes:@{NSForegroundColorAttributeName : [UIColor colorWithRed:0.788 green:0.569 blue:0.192 alpha:1]}];

    NSMutableString *callInfoStr = [NSMutableString stringWithFormat:@" "];
    for (NSUInteger i = 1; i < subCallTraceModel.callDepth; ++i) {
        [callInfoStr appendString:@"  "];
    }
    [callInfoStr appendFormat:@"[%@ %@]", subCallTraceModel.className, subCallTraceModel.methodName];
    NSAttributedString *callInfoAttrStr = [[NSAttributedString alloc] initWithString:callInfoStr];


    [mutAttrStr appendAttributedString:timeAttrStr];
    [mutAttrStr appendAttributedString:callInfoAttrStr];
    for (MTHCallTraceTimeCostModel *item in subCallTraceModel.subCosts) {
        [mutAttrStr appendAttributedString:[[NSAttributedString alloc] initWithString:@"\r"]];
        [mutAttrStr appendAttributedString:[self subCallTraceLineAttributesString:item]];
    }
    return [mutAttrStr copy];
}

// MARK: - getter
- (UILabel *)timeCostLabel {
    if (_timeCostLabel == nil) {
        _timeCostLabel = [[UILabel alloc] init];
        _timeCostLabel.font = [MTHUISkeletonUtility codeFontWithSize:kTimeCostLabelFont];
        _timeCostLabel.textColor = [UIColor colorWithRed:0.788 green:0.569 blue:0.192 alpha:1];
    }
    return _timeCostLabel;
}

- (UIScrollView *)scrollView {
    if (_scrollView == nil) {
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.bounces = NO;
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.backgroundColor = self.backgroundColor;
    }
    return _scrollView;
}

- (UILabel *)callInfoLabel {
    if (_callInfoLabel == nil) {
        _callInfoLabel = [[UILabel alloc] init];
        _callInfoLabel.font = [MTHUISkeletonUtility codeFontWithSize:kCallInfoLableFont];
        _callInfoLabel.textColor = [UIColor colorWithWhite:.2f alpha:1.f];
    }
    return _callInfoLabel;
}

- (UILabel *)subCallInfoLabel {
    if (_subCallInfoLabel == nil) {
        _subCallInfoLabel = [[UILabel alloc] init];
        _subCallInfoLabel.font = [MTHUISkeletonUtility codeFontWithSize:kSubCallInfoLabelFont];
        _subCallInfoLabel.textColor = [UIColor colorWithWhite:.2f alpha:1.f];
        _subCallInfoLabel.numberOfLines = 0;
    }
    return _subCallInfoLabel;
}

@end

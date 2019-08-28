//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/9
// Created by: EuanC
//


#import "MTHUITImeProfilerResultEventCell.h"
#import <MTHawkeye/MTHawkeyeUtility.h>
#import "MTHTimeRecord.h"
#import "UIColor+MTHawkeye.h"

#define kEventLabelFont 11
#define kEventExtraLabelFont 11
#define kVertSpace 5.f
#define kMarginVert 7.f
#define kMarginHorz 20.f


@interface MTHUITImeProfilerResultEventCell ()

@property (nonatomic, strong) MTHTimeIntervalCustomEventRecord *event;
@property (nonatomic, assign) BOOL expanded;

@property (nonatomic, strong) UIScrollView *scrollView;

@property (nonatomic, strong) UILabel *eventLabel;
@property (nonatomic, strong) UILabel *extraLabel;

@property (nonatomic, strong) NSDateFormatter *dateformatter;

@end


@implementation MTHUITImeProfilerResultEventCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        [self.contentView addSubview:self.scrollView];
        [self.scrollView setUserInteractionEnabled:NO];
        [self.contentView addGestureRecognizer:self.scrollView.panGestureRecognizer];

        [self.scrollView addSubview:self.eventLabel];
        [self.scrollView addSubview:self.extraLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat left = kMarginHorz;
    CGFloat top = kMarginVert;

    CGSize eventSize = [self.eventLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 20.f)];
    eventSize.width += kMarginHorz;
    self.eventLabel.frame = CGRectMake(0, 0, eventSize.width, eventSize.height);
    CGFloat scrollViewContentWidth = eventSize.width;
    CGFloat scrollViewContentHeight = eventSize.height;

    if (self.expanded) {
        CGSize extraSize = [self.extraLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
        extraSize.width += kMarginHorz;
        if (extraSize.width > scrollViewContentWidth)
            scrollViewContentWidth = extraSize.width;

        CGFloat y = CGRectGetMaxY(self.eventLabel.frame) + kVertSpace;
        self.extraLabel.frame = CGRectMake(0, y, extraSize.width, extraSize.height);
        scrollViewContentHeight = CGRectGetMaxY(self.extraLabel.frame);
    }

    CGRect scrollViewFrame = CGRectMake(left, top, CGRectGetMaxX(self.frame) - left, scrollViewContentHeight);
    self.scrollView.frame = scrollViewFrame;

    CGSize scrollViewContentSize = CGSizeMake(scrollViewContentWidth, scrollViewContentHeight);
    self.scrollView.contentSize = scrollViewContentSize;
}

- (void)configureWithEventRecord:(MTHTimeIntervalCustomEventRecord *)eventRecord
                        expanded:(BOOL)expanded {
    self.event = eventRecord;
    self.expanded = expanded;

    if (eventRecord.extra.length > 0) {
        self.eventLabel.text = [NSString stringWithFormat:@"%@ %@", self.expanded ? @"-" : @"+", eventRecord.event];
        self.extraLabel.text = [NSString stringWithFormat:@"  %@", eventRecord.extra];
    } else {
        self.eventLabel.text = eventRecord.event;
    }

    [self setNeedsLayout];
}

+ (CGFloat)heightForEventRecord:(MTHTimeIntervalCustomEventRecord *)eventRecord
                       expanded:(BOOL)expanded {
    if (expanded && eventRecord.extra.length > 0) {
        return 30.f + [self heightForEventExtra:eventRecord.extra];
    } else {
        return 30.f;
    }
}

+ (CGFloat)heightForEventExtra:(NSString *)eventExtra {
    NSDictionary *attr = @{
        NSFontAttributeName : [UIFont systemFontOfSize:kEventExtraLabelFont]
    };
    CGSize container = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
    CGRect rect = [eventExtra boundingRectWithSize:container
                                           options:NSStringDrawingUsesLineFragmentOrigin
                                        attributes:attr
                                           context:nil];
    return CGRectGetHeight(rect) + kVertSpace;
}

// MARK: - getter

- (UIScrollView *)scrollView {
    if (_scrollView == nil) {
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.bounces = NO;
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.backgroundColor = self.backgroundColor;
    }
    return _scrollView;
}

- (UILabel *)eventLabel {
    if (_eventLabel == nil) {
        _eventLabel = [[UILabel alloc] init];
        _eventLabel.font = [UIFont systemFontOfSize:kEventLabelFont];
        _eventLabel.textColor = [UIColor mth_dynamicLightColor:[UIColor colorWithWhite:.2f alpha:1.f]
                                                     darkColor:[UIColor colorWithWhite:.8f alpha:1.f]];
    }
    return _eventLabel;
}

- (UILabel *)extraLabel {
    if (_extraLabel == nil) {
        _extraLabel = [[UILabel alloc] init];
        _extraLabel.font = [UIFont systemFontOfSize:kEventExtraLabelFont];
        _extraLabel.textColor = [UIColor mth_dynamicLightColor:[UIColor colorWithWhite:.2f alpha:1.f]
                                                     darkColor:[UIColor colorWithWhite:.8f alpha:1.f]];
        _extraLabel.numberOfLines = 0;
    }
    return _extraLabel;
}

@end

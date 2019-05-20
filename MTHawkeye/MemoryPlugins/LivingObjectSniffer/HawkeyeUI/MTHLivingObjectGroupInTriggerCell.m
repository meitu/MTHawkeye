//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/121/14
// Created by: EuanC
//


#import "MTHLivingObjectGroupInTriggerCell.h"
#import "MTHLivingObjectInfo.h"


@interface MTHLivingObjectGroupInTriggerCell ()

@property (nonatomic, strong) UILabel *timeLabel;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UILabel *triggerLabel;
@property (nonatomic, strong) UILabel *instancesSummaryLabel;
@property (nonatomic, strong) UILabel *instancesDetailLabel;

@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end

@implementation MTHLivingObjectGroupInTriggerCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        [self.contentView addSubview:self.timeLabel];

        [self.contentView addSubview:self.scrollView];
        [self.scrollView setUserInteractionEnabled:NO];
        [self.contentView addGestureRecognizer:self.scrollView.panGestureRecognizer];

        [self.scrollView addSubview:self.triggerLabel];
        [self.scrollView addSubview:self.instancesSummaryLabel];
        [self.scrollView addSubview:self.instancesDetailLabel];

        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setDateFormat:@"HH:mm:ss:SSS"];

        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

#define kLeft 7.f
#define kTop 10.f
#define kBottom 10.f
#define kLabelLineHeight 14.f
#define kSpaceY 5.f

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat left = kLeft;
    CGFloat posY = kTop;
    CGFloat spaceV = kSpaceY;
    CGFloat scrollViewWidth = CGRectGetWidth(self.contentView.bounds) - left * 4;
    self.timeLabel.frame = CGRectMake(left, posY, scrollViewWidth, kLabelLineHeight);

    CGFloat scrollViewPosY = CGRectGetMaxY(self.timeLabel.frame) + spaceV;

    posY = 0;
    CGFloat maxWidth = 0;
    self.triggerLabel.frame = CGRectMake(0, posY, 0, kLabelLineHeight);
    [self.triggerLabel sizeToFit];
    maxWidth = CGRectGetWidth(self.triggerLabel.frame);

    posY += CGRectGetHeight(self.triggerLabel.frame) + spaceV;
    self.instancesSummaryLabel.frame = CGRectMake(0, posY, 0, kLabelLineHeight);
    [self.instancesSummaryLabel sizeToFit];
    if (CGRectGetWidth(self.instancesSummaryLabel.frame) > maxWidth) {
        maxWidth = CGRectGetWidth(self.instancesSummaryLabel.frame) + 1.f;
    }

    posY += CGRectGetHeight(self.instancesSummaryLabel.frame) + spaceV;
    self.instancesDetailLabel.frame = CGRectMake(0, posY, 0, kLabelLineHeight);
    [self.instancesDetailLabel sizeToFit];
    if (CGRectGetWidth(self.instancesDetailLabel.frame) > maxWidth) {
        maxWidth = CGRectGetWidth(self.instancesDetailLabel.frame) + 1.f;
    }

    self.scrollView.frame = CGRectMake(left * 2, scrollViewPosY, scrollViewWidth, CGRectGetMaxY(self.instancesDetailLabel.frame) + 1.f);
    CGSize scrollViewContentSize = CGSizeMake(maxWidth, CGRectGetHeight(self.scrollView.frame));
    self.scrollView.contentSize = scrollViewContentSize;
}

+ (CGFloat)cellHeight {
    return kTop + kBottom + kLabelLineHeight * 5 + kSpaceY * 3;
}

- (void)configureWithLivingInstancesGroup:(MTHLivingObjectGroupInTrigger *)group {
    NSString *date = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:group.trigger.startTime]];
    self.timeLabel.text = date;

    NSMutableString *triggerInfo = [NSMutableString stringWithFormat:@"Under: %@", group.trigger.name];
    if (group.trigger.nameExtra) {
        [triggerInfo appendFormat:@" [children: %@]", group.trigger.nameExtra];
    }
    self.triggerLabel.text = triggerInfo.copy;

    NSInteger liveCount = 0;
    NSInteger releasedCount = 0;
    NSMutableString *instancesDetail = [NSMutableString string];
    for (MTHLivingObjectInfo *obj in group.detectedInstances) {
        if (obj.instance) {
            liveCount++;

            if (instancesDetail.length == 0)
                [instancesDetail appendString:@"Living: "];

            if (obj.theHodlerIsNotOwner) {
                [instancesDetail appendFormat:@"%@->%p[shared], ", obj.preHolderName, (void *)obj.instance];
            } else if (obj.isSingleton) {
                [instancesDetail appendFormat:@"%@->%p[singleton], ", obj.preHolderName, (void *)obj.instance];
            } else {
                [instancesDetail appendFormat:@"%@->%p, ", obj.preHolderName, (void *)obj.instance];
            }
        } else {
            releasedCount++;
        }
    }
    if (instancesDetail.length > 2)
        [instancesDetail deleteCharactersInRange:NSMakeRange(instancesDetail.length - 2, 2)];

    self.instancesDetailLabel.text = instancesDetail.copy;

    NSMutableString *instancesSummary = [NSMutableString string];
    if (liveCount > 0) {
        [instancesSummary appendFormat:@"%@ living", @(liveCount)];
    }
    if (releasedCount > 0) {
        if (instancesSummary.length > 0)
            [instancesSummary appendString:@", "];

        [instancesSummary appendFormat:@"%@ delay released", @(releasedCount)];
    }
    [instancesSummary appendFormat:@" instances:\n"];
    self.instancesSummaryLabel.text = instancesSummary.copy;

    [self setNeedsLayout];
}

- (UILabel *)timeLabel {
    if (_timeLabel == nil) {
        _timeLabel = [[UILabel alloc] init];
        _timeLabel.font = [UIFont systemFontOfSize:11];
        _timeLabel.textColor = [UIColor colorWithWhite:.5f alpha:1.f];
    }
    return _timeLabel;
}

- (UILabel *)triggerLabel {
    if (_triggerLabel == nil) {
        _triggerLabel = [[UILabel alloc] init];
        _triggerLabel.font = [UIFont systemFontOfSize:13];
        _triggerLabel.textColor = [UIColor colorWithWhite:.2f alpha:1.f];
    }
    return _triggerLabel;
}

- (UILabel *)instancesSummaryLabel {
    if (_instancesSummaryLabel == nil) {
        _instancesSummaryLabel = [[UILabel alloc] init];
        _instancesSummaryLabel.font = [UIFont systemFontOfSize:13];
        _instancesSummaryLabel.textColor = [UIColor colorWithWhite:.2f alpha:1.f];
    }
    return _instancesSummaryLabel;
}

- (UILabel *)instancesDetailLabel {
    if (_instancesDetailLabel == nil) {
        _instancesDetailLabel = [[UILabel alloc] init];
        _instancesDetailLabel.font = [UIFont systemFontOfSize:13];
        _instancesDetailLabel.textColor = [UIColor colorWithWhite:.2f alpha:1.f];
    }
    return _instancesDetailLabel;
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

@end

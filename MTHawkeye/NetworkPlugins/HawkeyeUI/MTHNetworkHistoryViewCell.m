//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 17/07/2017
// Created by: EuanC
//


#import "MTHNetworkHistoryViewCell.h"
#import "MTHNetworkTaskAdvice.h"
#import "MTHNetworkTransaction.h"

#import <MTHawkeye/MTHUISkeletonUtility.h>


NSString *const MTNetworkHistoryViewCellIdentifier = @"kMTNetworkTransactionCellIdentifier";


@interface MTHNetworkHistoryViewCell ()

@property (nonatomic, strong) UIButton *detailBtnView;

@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *pathLabel;
@property (nonatomic, strong) UILabel *transactionDetailsLabel;

@property (nonatomic, strong) UILabel *advicesTipLabel;

@end


@implementation MTHNetworkHistoryViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        self.detailBtnView = [[UIButton alloc] init];
        UIImage *bgImage = [self _imageFromColor:[UIColor colorWithWhite:0.8 alpha:0.1f]];
        [self.detailBtnView setBackgroundImage:bgImage forState:UIControlStateNormal];
        [self.detailBtnView addTarget:self action:@selector(detailBtnTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.detailBtnView];

        self.nameLabel = [[UILabel alloc] init];
        self.nameLabel.font = [UIFont systemFontOfSize:10.f];
        self.nameLabel.textColor = [UIColor colorWithWhite:0.0667 alpha:1];
        [self.contentView addSubview:self.nameLabel];

        self.pathLabel = [[UILabel alloc] init];
        self.pathLabel.font = [UIFont systemFontOfSize:10.f];
        self.pathLabel.textColor = [UIColor colorWithWhite:0.333 alpha:1];
        [self.contentView addSubview:self.pathLabel];

        self.transactionDetailsLabel = [[UILabel alloc] init];
        self.transactionDetailsLabel.font = [UIFont systemFontOfSize:10.f];
        self.transactionDetailsLabel.textColor = [UIColor colorWithWhite:0.533 alpha:1];
        [self.contentView addSubview:self.transactionDetailsLabel];

        self.advicesTipLabel = [[UILabel alloc] init];
        self.advicesTipLabel.textAlignment = NSTextAlignmentRight;
        UIFont *advicesTipLabelFont = [UIFont fontWithName:@"Menlo" size:12.f];
        if (!advicesTipLabelFont) {
            advicesTipLabelFont = [UIFont fontWithName:@"Courier" size:12.f];
        }
        self.advicesTipLabel.font = advicesTipLabelFont;
        self.advicesTipLabel.textColor = [UIColor colorWithWhite:0.533 alpha:1];
        [self.contentView addSubview:self.advicesTipLabel];
    }
    return self;
}

- (void)setTransaction:(MTHNetworkTransaction *)transaction {
    if (_transaction != transaction) {
        _transaction = transaction;
        [self setNeedsLayout];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    const CGFloat left = 10.f;
    const CGFloat top = 10.f;
    const CGFloat lineSpacing = 3.5f;
    const CGFloat labelHeight = 12.f;
    const CGFloat detailBtnWidth = 47.f;
    const CGFloat availabelTextWidth = self.bounds.size.width - left * 2 - detailBtnWidth;

    CGFloat btnLeft = self.bounds.size.width - detailBtnWidth;
    CGRect detailBtnFrame = CGRectMake(btnLeft, 0, detailBtnWidth, self.bounds.size.height);
    self.detailBtnView.frame = detailBtnFrame;

    CGFloat advicesTipLeft = self.bounds.size.width - 50.f - 3.f;
    CGRect advicesTipFrame = CGRectMake(advicesTipLeft, 3.f, 50.f, 14.f);
    self.advicesTipLabel.frame = advicesTipFrame;
    if (self.advices.count == 0) {
        self.advicesTipLabel.hidden = YES;
    } else {
        self.advicesTipLabel.hidden = NO;
        self.advicesTipLabel.attributedText = [self advicesTipAttributeText];
    }

    self.nameLabel.text = [self nameLabelText];
    self.nameLabel.frame = CGRectMake(left, top, availabelTextWidth, labelHeight);
    self.nameLabel.textColor = self.transaction.error ? [UIColor colorWithRed:0.816 green:0.00392 blue:0.106 alpha:1] : [UIColor colorWithWhite:0.0667 alpha:1];

    CGFloat posY = top + labelHeight + lineSpacing;
    self.pathLabel.text = [self pathLabelText];
    self.pathLabel.frame = CGRectMake(left, posY, availabelTextWidth, labelHeight);

    self.transactionDetailsLabel.text = [self transactionDetailsLabelText];
    posY += labelHeight + lineSpacing;
    self.transactionDetailsLabel.frame = CGRectMake(left, posY, availabelTextWidth, labelHeight);

    switch (self.status) {
        case MTHNetworkHistoryViewCellStatusDefault:
            self.backgroundColor = [UIColor whiteColor];
            break;
        case MTHNetworkHistoryViewCellStatusOnWaterfall:
            self.backgroundColor = [UIColor colorWithRed:0.933 green:0.933 blue:0.941 alpha:1];
            break;
        case MTHNetworkHistoryViewCellStatusOnFocus:
            self.backgroundColor = [UIColor colorWithRed:0.843 green:0.91 blue:0.988 alpha:1];
            break;
        default:
            break;
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
}

- (void)setStatus:(MTHNetworkHistoryViewCellStatus)status {
    _status = status;

    [self setNeedsLayout];
}

// MARK:
- (void)detailBtnTapped {
    if ([self.delegate respondsToSelector:@selector(mt_networkHistoryViewCellDidTappedDetail:)]) {
        [self.delegate mt_networkHistoryViewCellDidTappedDetail:self];
    }
}

// MARK: -
- (NSMutableAttributedString *)advicesTipAttributeText {
    NSMutableAttributedString *str = [[NSMutableAttributedString alloc] init];
    NSInteger totalCount = 0, highCount = 0, middleCount = 0, lowCount = 0;
    totalCount = self.advices.count;
    for (MTHNetworkTaskAdvice *advice in self.advices) {
        if (self.warningAdviceTypeIDs) {
            BOOL isEnabled = NO;
            for (NSString *typeID in self.warningAdviceTypeIDs) {
                if ([advice.typeId isEqualToString:typeID]) {
                    isEnabled = YES;
                    break;
                }
            }
            if (!isEnabled) {
                continue;
            }
        }
        highCount += (advice.level == MTHNetworkTaskAdviceLevelHigh) ? 1 : 0;
        middleCount += (advice.level == MTHNetworkTaskAdviceLevelMiddle) ? 1 : 0;
        lowCount += (advice.level == MTHNetworkTaskAdviceLevelLow) ? 1 : 0;
    }

    NSInteger columnCount = 3;
    if (highCount == 0 || middleCount == 0 || lowCount == 0) {
        columnCount--;
    }

    if (highCount == totalCount || middleCount == totalCount || lowCount == totalCount) {
        columnCount--;
    }

    if (highCount > 0) {
        NSString *infoText = [NSString stringWithFormat:@"%@", @(highCount)];
        NSDictionary *attributes = @{NSForegroundColorAttributeName : [UIColor colorWithRed:0.816 green:0.00784 blue:0.106 alpha:1]};
        NSAttributedString *highInfo = [[NSAttributedString alloc] initWithString:infoText attributes:attributes];
        [str appendAttributedString:highInfo];

        if (columnCount > 1) {
            NSAttributedString *slash = [[NSAttributedString alloc] initWithString:@"/" attributes:nil];
            [str appendAttributedString:slash];
        }
    }
    if (middleCount > 0) {
        NSString *infoText = [NSString stringWithFormat:@"%@", @(middleCount)];
        NSDictionary *attributes = @{NSForegroundColorAttributeName : [UIColor colorWithRed:1 green:0.455 blue:0.455 alpha:1]};
        NSAttributedString *middleInfo = [[NSAttributedString alloc] initWithString:infoText attributes:attributes];
        [str appendAttributedString:middleInfo];

        if (columnCount > 1) {
            NSAttributedString *slash = [[NSAttributedString alloc] initWithString:@"/" attributes:nil];
            [str appendAttributedString:slash];
        }
    }
    if (lowCount > 0) {
        NSString *infoText = [NSString stringWithFormat:@"%@", @(lowCount)];
        NSDictionary *attributes = @{NSForegroundColorAttributeName : [UIColor colorWithWhite:0.533 alpha:1]};
        NSAttributedString *lowInfo = [[NSAttributedString alloc] initWithString:infoText attributes:attributes];
        [str appendAttributedString:lowInfo];
    }
    return str;
}

- (NSString *)nameLabelText {
    NSURL *url = self.transaction.request.URL;
    NSString *name = [NSString stringWithFormat:@"%@: %@", @(self.transaction.requestIndex), [url lastPathComponent]];
    if ([name length] == 0) {
        name = @"/";
    }
    NSString *query = [url query];
    if (query) {
        name = [name stringByAppendingFormat:@"?%@", query];
    }
    return name;
}

- (NSString *)pathLabelText {
    NSURL *url = self.transaction.request.URL;
    NSMutableArray *mutablePathComponents = [[url pathComponents] mutableCopy];
    if ([mutablePathComponents count] > 0) {
        [mutablePathComponents removeLastObject];
    }
    NSString *path = [url host];
    for (NSString *pathComponent in mutablePathComponents) {
        path = [path stringByAppendingPathComponent:pathComponent];
    }
    return path;
}

- (NSString *)transactionDetailsLabelText {
    NSMutableArray *detailComponents = [NSMutableArray array];

    NSString *timestamp = [[self class] timestampStringFromRequestDate:self.transaction.startTime];
    if ([timestamp length] > 0) {
        [detailComponents addObject:timestamp];
    }

    // Omit method for GET (assumed as default)
    NSString *httpMethod = self.transaction.request.HTTPMethod;
    if ([httpMethod length] > 0) {
        [detailComponents addObject:httpMethod];
    }

    if (self.transaction.transactionState == MTHNetworkTransactionStateFinished || self.transaction.transactionState == MTHNetworkTransactionStateFailed) {
        NSString *statusCodeString = [MTHUISkeletonUtility statusCodeStringFromURLResponse:self.transaction.response];
        if ([statusCodeString length] > 0) {
            [detailComponents addObject:statusCodeString];
        }

        if (self.transaction.receivedDataLength > 0) {
            NSString *responseSize = [NSByteCountFormatter stringFromByteCount:self.transaction.receivedDataLength countStyle:NSByteCountFormatterCountStyleBinary];
            if (responseSize) {
                [detailComponents addObject:responseSize];
            }
        }

        NSString *totalDuration = [MTHUISkeletonUtility stringFromRequestDuration:self.transaction.duration];
        NSString *latency = [MTHUISkeletonUtility stringFromRequestDuration:self.transaction.latency];
        NSString *duration = [NSString stringWithFormat:@"%@ (%@)", totalDuration, latency];
        [detailComponents addObject:duration];

        NSInteger totalFlow = self.transaction.requestLength + self.transaction.responseLength;
        NSString *flowStr = [NSByteCountFormatter stringFromByteCount:totalFlow countStyle:NSByteCountFormatterCountStyleBinary];
        [detailComponents addObject:flowStr];

    } else {
        // Unstarted, Awaiting Response, Receiving Data, etc.
        NSString *state = [MTHNetworkTransaction readableStringFromTransactionState:self.transaction.transactionState];
        [detailComponents addObject:state];
    }

    return [detailComponents componentsJoinedByString:@"・"];
}

+ (NSString *)timestampStringFromRequestDate:(NSDate *)date {
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"HH:mm:ss";
    });
    return [dateFormatter stringFromDate:date];
}

+ (CGFloat)preferredCellHeight {
    return 64.0f;
}

- (UIImage *)_imageFromColor:(UIColor *)color {
    CGRect rect = CGRectMake(0, 0, 4, 4);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end

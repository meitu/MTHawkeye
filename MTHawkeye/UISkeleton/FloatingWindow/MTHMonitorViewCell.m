//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 30/06/2017
// Created by: EuanC
//


#import "MTHMonitorViewCell.h"
#import "MTHMonitorViewConfiguration.h"


@interface MTHMonitorViewCell ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UILabel *infoLabel;

@property (nonatomic, strong) UIColor *valueColor;
@property (nonatomic, strong) UIColor *unitColor;

@property (nonatomic, copy) NSString *value;
@property (nonatomic, copy) NSString *unit;

@property (nonatomic, assign) BOOL underWarningColor;

@end


@implementation MTHMonitorViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        [self setup];
    }
    return self;
}

- (instancetype)init {
    if ((self = [self initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"hawkeye-monitor-cell"])) {
    }
    return self;
}

- (void)setup {
    self.backgroundColor = [UIColor clearColor];
    [self.contentView addSubview:self.scrollView];
    [self.scrollView addSubview:self.infoLabel];

    self.valueColor = MTHMonitorViewConfiguration.valueColor;
    self.unitColor = MTHMonitorViewConfiguration.unitColor;
}

- (void)updateWithString:(NSString *)content {
    [self updateWithString:content color:nil];
}

- (void)updateWithString:(NSString *)content color:(UIColor *)color {
    [self updateWithValue:content valueColor:color unit:nil unitColor:nil];
}

- (void)updateWithValue:(NSString *)value unit:(NSString *)unit {
    [self updateWithValue:value
               valueColor:self.valueColor
                     unit:unit
                unitColor:self.unitColor];
}

- (void)updateWithValue:(NSString *)value
             valueColor:(UIColor *)valueColor
                   unit:(NSString *)unit
              unitColor:(UIColor *)unitColor {
    if (value.length > 0)
        self.value = value;
    if (unit.length > 0)
        self.unit = unit;

    NSMutableAttributedString *str = [[NSMutableAttributedString alloc] init];
    if (self.value.length > 0) {
        NSDictionary *valueAttr = @{
            NSForegroundColorAttributeName : valueColor ?: self.valueColor,
            NSFontAttributeName : MTHMonitorViewConfiguration.valueFont
        };
        NSAttributedString *valueStr = [[NSAttributedString alloc] initWithString:self.value ?: @"" attributes:valueAttr];
        [str appendAttributedString:valueStr];
    }

    if (self.unit.length > 0) {
        NSDictionary *unitAttr = @{
            NSForegroundColorAttributeName : unitColor ?: self.unitColor,
            NSFontAttributeName : MTHMonitorViewConfiguration.unitFont
        };
        NSString *unitFix = [NSString stringWithFormat:@" %@", self.unit ?: @""];
        NSAttributedString *unitStr = [[NSAttributedString alloc] initWithString:unitFix attributes:unitAttr];
        [str appendAttributedString:unitStr];
    }

    [self updateWithAttributeString:[str copy]];
}

- (void)updateWithAttributeString:(NSAttributedString *)content {
    CGFloat cellWidth = MTHMonitorViewConfiguration.monitorWidth;
    self.scrollView.frame = CGRectMake(0, 0, cellWidth, MTHMonitorViewConfiguration.monitorCellHeight);

    self.infoLabel.attributedText = content;

    [self.infoLabel sizeToFit];
    CGSize size = self.infoLabel.bounds.size;
    if (size.width <= (cellWidth - 3)) {
        size.width = (cellWidth - 3);
        self.infoLabel.frame = CGRectMake(0, 0, size.width, size.height);
    }

    self.scrollView.contentSize = self.infoLabel.bounds.size;
}

- (void)flashingWithDuration:(CGFloat)durationInSeconds
                       color:(UIColor *)flashColor {
    static BOOL flashing = NO;
    if (flashing)
        return;

    flashing = YES;
    if (durationInSeconds <= 0.f)
        durationInSeconds = 5.f;

    __weak typeof(self) weak_self = self;
    [self flashingWithDuration:durationInSeconds
        toWarningSignalHandler:^{
            [weak_self updateWithValue:nil valueColor:flashColor unit:nil unitColor:flashColor];
        }
        reverseSignalHandler:^{
            [weak_self updateWithValue:nil valueColor:weak_self.valueColor unit:nil unitColor:weak_self.unitColor];
        }
        completion:^{
            flashing = NO;
        }];
}

- (void)flashingWithDuration:(CGFloat)duration
      toWarningSignalHandler:(void (^)(void))toWarningSignalHandler
        reverseSignalHandler:(void (^)(void))reverseSignalHandler
                  completion:(void (^)(void))completion {

    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, .4f * NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(timer, ^{
        @autoreleasepool {
            if (self.underWarningColor) {
                toWarningSignalHandler();
                self.underWarningColor = NO;
            } else {
                reverseSignalHandler();
                self.underWarningColor = YES;
            }
        }
    });
    dispatch_resume(timer);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        dispatch_source_cancel(timer);
        reverseSignalHandler();

        completion();
    });
}

// MARK: - getter

- (UIScrollView *)scrollView {
    if (_scrollView == nil) {
        _scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
        _scrollView.backgroundColor = [UIColor clearColor];
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.showsHorizontalScrollIndicator = NO;
    }
    return _scrollView;
}

- (UILabel *)infoLabel {
    if (_infoLabel == nil) {
        _infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
        _infoLabel.font = MTHMonitorViewConfiguration.valueFont;
        _infoLabel.numberOfLines = 1;
        _infoLabel.textAlignment = NSTextAlignmentRight;
        _infoLabel.textColor = MTHMonitorViewConfiguration.valueColor;
    }
    return _infoLabel;
}

@end

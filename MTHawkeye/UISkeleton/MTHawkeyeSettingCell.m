//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/14
// Created by: EuanC
//


#import "MTHawkeyeSettingCell.h"
#import "MTHawkeyeSettingTableEntity.h"
#import "UIColor+MTHawkeye.h"

@interface MTHawkeyeSettingCell () <MTHawkeyeSettingCellEntityDelegate>

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UISwitch *switchCtrl;
@property (nonatomic, strong) UILabel *valueLabel;

@end


@implementation MTHawkeyeSettingCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        [self.contentView addSubview:self.titleLabel];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setModel:(MTHawkeyeSettingCellEntity *)model {
    _model = model;
    model.delegate = self;

    self.titleLabel.text = self.model.title;
    [self.titleLabel sizeToFit];
    CGFloat centerX = 15.f + CGRectGetWidth(self.titleLabel.bounds) / 2.f;
    CGFloat centerY = ceil(CGRectGetHeight(self.bounds) / 2.f);
    CGPoint center = CGPointMake(centerX, centerY);
    self.titleLabel.center = center;

    self.valueLabel.text = nil;

    [self.switchCtrl removeFromSuperview];
    [self.valueLabel removeFromSuperview];

    self.accessoryType = UITableViewCellAccessoryNone;
    self.accessoryView = nil;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;

    if ([self.model isKindOfClass:[MTHawkeyeSettingEditorCellEntity class]]) {
        MTHawkeyeSettingEditorCellEntity *editorEntity = (MTHawkeyeSettingEditorCellEntity *)self.model;
        NSString *valueText = editorEntity.setupValueHandler();
        if (editorEntity.valueUnits.length > 0)
            valueText = [valueText stringByAppendingString:editorEntity.valueUnits ?: @""];
        self.valueLabel.text = valueText;
    } else if ([self.model isKindOfClass:[MTHawkeyeSettingSwitcherCellEntity class]]) {
        self.switchCtrl.hidden = NO;
        self.switchCtrl.on = ((MTHawkeyeSettingSwitcherCellEntity *)self.model).setupValueHandler();
        self.accessoryView = self.switchCtrl;
        self.switchCtrl.enabled = !self.model.frozen;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self.contentView addSubview:self.switchCtrl];
    } else if ([self.model isKindOfClass:[MTHawkeyeSettingSelectorCellEntity class]]) {
        MTHawkeyeSettingSelectorCellEntity *selector = (MTHawkeyeSettingSelectorCellEntity *)self.model;
        NSUInteger selectedIndex = selector.setupSelectedIndexHandler();
        if (selectedIndex < selector.options.count)
            self.valueLabel.text = [selector.options objectAtIndex:selectedIndex];

    } else if ([self.model isKindOfClass:[MTHawkeyeSettingFoldedCellEntity class]]) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if ([self.model isKindOfClass:[MTHawkeyeSettingActionCellEntity class]]) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    if (self.valueLabel.text.length > 0) {
        self.valueLabel.hidden = NO;
        [self.valueLabel sizeToFit];
        CGFloat maxWidth = CGRectGetWidth(self.bounds) - CGRectGetWidth(self.titleLabel.bounds) - 45.f;
        if (CGRectGetWidth(self.valueLabel.bounds) > maxWidth) {
            CGRect fixBounds = self.valueLabel.bounds;
            fixBounds.size.width = maxWidth;
            self.valueLabel.bounds = fixBounds;
        }
        self.accessoryView = self.valueLabel;
    }
}

- (void)stateChanged:(UISwitch *)switchView {
    if ([self.model isKindOfClass:[MTHawkeyeSettingSwitcherCellEntity class]]) {
        MTHawkeyeSettingSwitcherCellEntity *switcher = (MTHawkeyeSettingSwitcherCellEntity *)self.model;
        if (switcher.valueChangedHandler) {
            switcher.valueChangedHandler(switchView.isOn);
        }
    };
}

// MARK: - MTHawkeyeSettingCellViewModelEntityDelegate
- (void)hawkeyeSettingEntityValueDidChanged:(MTHawkeyeSettingCellEntity *)entity {
    // simply reload data.
    [self setModel:_model];
}

// MARK: -
- (UILabel *)titleLabel {
    if (_titleLabel == nil) {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont systemFontOfSize:17];
        _titleLabel.textColor = [UIColor mth_dynamicComplementaryColor:[UIColor colorWithRed:0.0118 green:0.0118 blue:0.0118 alpha:1]];
    }
    return _titleLabel;
}

- (UISwitch *)switchCtrl {
    if (_switchCtrl == nil) {
        _switchCtrl = [[UISwitch alloc] init];
        [_switchCtrl addTarget:self action:@selector(stateChanged:) forControlEvents:UIControlEventValueChanged];
    }
    return _switchCtrl;
}

- (UILabel *)valueLabel {
    if (_valueLabel == nil) {
        _valueLabel = [[UILabel alloc] init];
        _valueLabel.font = [UIFont systemFontOfSize:17];
        _valueLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        _valueLabel.textColor = [UIColor colorWithRed:0.561 green:0.557 blue:0.58 alpha:1];
    }
    return _valueLabel;
}


@end

//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/121/18
// Created by: David.Dai
//


#import "MTHDirectoryWatcherSelctionTableViewCell.h"
#import "MTHawkeyeUserDefaults+DirectorWatcher.h"
@interface MTHDirectoryWatcherSelctionTableViewCell ()
@property (nonatomic, strong) UISwitch *watchingSwitch;
@end

@implementation MTHDirectoryWatcherSelctionTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        [self addSubview:self.watchingSwitch];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self addSubview:self.watchingSwitch];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect frame = self.frame;
    self.watchingSwitch.frame = CGRectMake((frame.size.width - 51 - 35), (frame.size.height - 31) / 2, 51, 31);
}

- (UISwitch *)watchingSwitch {
    if (!_watchingSwitch) {
        _watchingSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
        [_watchingSwitch addTarget:self action:@selector(switchChange:) forControlEvents:UIControlEventValueChanged];
    }
    return _watchingSwitch;
}

- (void)setHaveChild:(BOOL)haveChild {
    _haveChild = haveChild;
    self.accessoryType = haveChild ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
}

- (void)switchChange:(UISwitch *)sender {
    self.isWatching = sender.on;
    if (self.switchBlock) {
        self.switchBlock();
    }
}

- (void)setIsWatching:(BOOL)isWatching {
    _isWatching = isWatching;
    if (isWatching) {
        if (![[MTHawkeyeUserDefaults shared].directoryWatcherFoldersPath containsObject:_path]) {
            [MTHawkeyeUserDefaults shared].directoryWatcherFoldersPath = [[MTHawkeyeUserDefaults shared].directoryWatcherFoldersPath arrayByAddingObject:_path];
        }
    } else {
        if ([[MTHawkeyeUserDefaults shared].directoryWatcherFoldersPath containsObject:_path]) {
            [MTHawkeyeUserDefaults shared].directoryWatcherFoldersPath = [[MTHawkeyeUserDefaults shared].directoryWatcherFoldersPath filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self != %@", _path]];
        }
    }
    [self.watchingSwitch setOn:isWatching];
}

- (void)setPath:(NSString *)path {
    _path = path;
    self.textLabel.text = [path lastPathComponent];
}
@end

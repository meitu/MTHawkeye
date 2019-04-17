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


#import "MTHawkeyeMainPanelSwitchViewController.h"


@interface MTHawkeyeMainPanelSwitchViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak) id<MTHawkeyeMainPanelSwitcherDelegate> delegate;

@property (nonatomic, assign) CGFloat cellHeight;

@property (nonatomic, strong) UITableView *leftTable;
@property (nonatomic, strong) UITableView *rightTable;
@property (nonatomic, strong) UIColor *rightTableDefaultColor;
@property (nonatomic, strong) UIColor *rightTableSelectColor;

@property (nonatomic, strong) NSIndexPath *selectedIndexPath;
@property (nonatomic, strong) NSIndexPath *highlightIndexPath;

@end


@implementation MTHawkeyeMainPanelSwitchViewController

- (instancetype)initWithSelectedIndexPath:(NSIndexPath *)selectedIndexPath
                                 delegate:(id<MTHawkeyeMainPanelSwitcherDelegate>)delegate {
    if (self = [super init]) {
        _selectedIndexPath = selectedIndexPath;
        _highlightIndexPath = selectedIndexPath;
        _delegate = delegate;
        _cellHeight = 44.f;

        _rightTableDefaultColor = [UIColor colorWithWhite:0.97 alpha:1.f];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.view addSubview:self.leftTable];
    [self.view addSubview:self.rightTable];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];

    CGFloat fullWidth = CGRectGetWidth(self.view.bounds);
    CGFloat fullHeight = CGRectGetHeight(self.view.bounds);
    CGFloat leftWidth = ceil(fullWidth * 0.45f);
    self.leftTable.frame = CGRectMake(0, 0, leftWidth, fullHeight);
    self.rightTable.frame = CGRectMake(leftWidth, 0, fullWidth - leftWidth, fullHeight);
}

- (CGFloat)fullContentHeight {
    return [self.delegate numberOfSwitcherOptionsSection] * self.cellHeight;
}

// MARK: - UITableViewDatasource

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.cellHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.leftTable) {
        return [self.delegate numberOfSwitcherOptionsSection];
    } else {
        return [self.delegate numberOfSwitcherOptionsRowAtSection:self.highlightIndexPath.section];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"hawkeye-switcher-cell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"hawkeye-switcher-cell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    NSString *title;
    if (tableView == self.leftTable) {
        title = [self.delegate switcherOptionsSectionTitleAtIndex:indexPath.row];
        if (indexPath.row == self.highlightIndexPath.section) {
            cell.backgroundColor = self.rightTableDefaultColor;
            cell.textLabel.textColor = [UIColor blackColor];
        } else {
            cell.backgroundColor = [UIColor whiteColor];
            cell.textLabel.textColor = [UIColor darkGrayColor];
        }
    } else {
        NSIndexPath *fixIndexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:self.highlightIndexPath.section];
        title = [self.delegate switcherOptionsTitleAtIndexPath:fixIndexPath];

        cell.backgroundColor = self.rightTableDefaultColor;

        if (fixIndexPath.row == self.selectedIndexPath.row && fixIndexPath.section == self.selectedIndexPath.section) {
            cell.textLabel.textColor = [UIColor blackColor];
        } else {
            cell.textLabel.textColor = [UIColor grayColor];
        }
    }
    cell.textLabel.text = title;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.leftTable) {
        if (indexPath.row == self.highlightIndexPath.section)
            return;

        self.highlightIndexPath = [NSIndexPath indexPathForRow:-1 inSection:indexPath.row];

        [self.leftTable reloadData];
        [self.rightTable reloadData];
    } else {
        NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:self.highlightIndexPath.section];
        BOOL changeSelect = [self.delegate shouldChangeSelectStatusToNew:newIndexPath fromOld:self.selectedIndexPath];
        if (changeSelect) {
            self.highlightIndexPath = newIndexPath;
            self.selectedIndexPath = newIndexPath;

            [self.rightTable reloadData];
        }
        [self.delegate panelSwitcherDidSelectAtIndexPath:newIndexPath];
    }
}

// MARK: - getter
- (UITableView *)leftTable {
    if (_leftTable == nil) {
        _leftTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _leftTable.delegate = self;
        _leftTable.dataSource = self;
        _leftTable.separatorStyle = UITableViewCellSeparatorStyleNone;
        _leftTable.tableFooterView = [UIView new];
    }
    return _leftTable;
}

- (UITableView *)rightTable {
    if (_rightTable == nil) {
        _rightTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _rightTable.delegate = self;
        _rightTable.dataSource = self;
        _rightTable.separatorStyle = UITableViewCellSeparatorStyleNone;
        _rightTable.tableFooterView = [UIView new];
        _rightTable.backgroundColor = self.rightTableDefaultColor;
    }
    return _rightTable;
}

@end

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


#import "MTHawkeyeSettingViewController.h"
#import "MTHawkeyeInputAlert.h"
#import "MTHawkeyeSettingCell.h"

@interface MTHawkeyeSettingViewController ()

@property (nonatomic, strong) MTHawkeyeSettingTableEntity *viewModelEntity;

@end

@implementation MTHawkeyeSettingViewController

- (instancetype)initWithTitle:(NSString *)title
              viewModelEntity:(MTHawkeyeSettingTableEntity *)entity {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.title = title;
        self.viewModelEntity = entity;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.tableView registerClass:[MTHawkeyeSettingCell class] forCellReuseIdentifier:@"mt-hawkeye-setting"];
}

- (NSInteger)numberOfSection {
    return self.viewModelEntity.sections.count;
}

- (MTHawkeyeSettingSectionEntity *)sectionAtIndex:(NSInteger)sectionIndex {
    if (sectionIndex < self.viewModelEntity.sections.count) {
        return self.viewModelEntity.sections[sectionIndex];
    }
    return nil;
}

- (MTHawkeyeSettingCellEntity *)cellViewModelAtIndexPath:(NSIndexPath *)indexPath {
    MTHawkeyeSettingSectionEntity *sectionModel = [self sectionAtIndex:indexPath.section];
    if (sectionModel && sectionModel.cells.count > indexPath.row)
        return sectionModel.cells[indexPath.row];
    else
        return nil;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self numberOfSection];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self sectionAtIndex:section].cells.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MTHawkeyeSettingCell *cell = [tableView dequeueReusableCellWithIdentifier:@"mt-hawkeye-setting" forIndexPath:indexPath];
    MTHawkeyeSettingCellEntity *cellModel = [self cellViewModelAtIndexPath:indexPath];
    cell.model = cellModel;
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *header = [self sectionAtIndex:section].headerText;
    return header.length > 0 ? header : @"";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSString *footer = [self sectionAtIndex:section].footerText;
    return footer.length > 0 ? footer : @"";
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    NSString *header = [self sectionAtIndex:section].headerText;
    ((UITableViewHeaderFooterView *)view).textLabel.text = header;
}

// MARK: -
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    MTHawkeyeSettingCellEntity *cellModel = [self cellViewModelAtIndexPath:indexPath];
    if (!cellModel)
        return;

    if (cellModel.frozen)
        return;

    if ([cellModel isKindOfClass:[MTHawkeyeSettingEditorCellEntity class]]) {
        [self showEditorForCellModel:(MTHawkeyeSettingEditorCellEntity *)cellModel atIndexPath:indexPath];
    } else if ([cellModel isKindOfClass:[MTHawkeyeSettingFoldedCellEntity class]]) {
        [self showDetailForCellModel:(MTHawkeyeSettingFoldedCellEntity *)cellModel];
    } else if ([cellModel isKindOfClass:[MTHawkeyeSettingActionCellEntity class]]) {
        [self trigerActionForCellModel:(MTHawkeyeSettingActionCellEntity *)cellModel];
    } else if ([cellModel isKindOfClass:[MTHawkeyeSettingSelectorCellEntity class]]) {
        [self showSelectorForCellModel:(MTHawkeyeSettingSelectorCellEntity *)cellModel];
    }
}

- (void)showEditorForCellModel:(MTHawkeyeSettingEditorCellEntity *)viewModel atIndexPath:(NSIndexPath *)indexPath {
    [MTHawkeyeInputAlert
        showInputAlertWithTitle:viewModel.title
        messgage:viewModel.inputTips
        from:self
        textFieldSetupHandler:^(UITextField *_Nonnull textField) {
            textField.keyboardType = viewModel.editorKeyboardType;
            textField.text = viewModel.setupValueHandler();
        }
        confirmHandler:^(UITextField *_Nonnull textField) {
            NSString *newValue = textField.text;
            if (viewModel.valueChangedHandler(newValue)) {
                [self.tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
            }
        }
        cancelHandler:nil];
}


- (void)trigerActionForCellModel:(MTHawkeyeSettingActionCellEntity *)cellModel {
    if (cellModel.didTappedHandler) {
        cellModel.didTappedHandler();
    }
}

- (void)showSelectorForCellModel:(MTHawkeyeSettingSelectorCellEntity *)cellModel {
    // TODO: implement selector.
}

- (void)showDetailForCellModel:(MTHawkeyeSettingFoldedCellEntity *)cellModel {
    MTHawkeyeSettingTableEntity *entity = [[MTHawkeyeSettingTableEntity alloc] init];
    entity.sections = cellModel.foldedSections;
    MTHawkeyeSettingViewController *vc = [[MTHawkeyeSettingViewController alloc] initWithTitle:cellModel.title viewModelEntity:entity];
    [self.navigationController pushViewController:vc animated:YES];
}

@end

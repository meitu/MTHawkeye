//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2017/9/1
// Created by: 潘名扬
//


#import "MTHNetworkTransactionAdviceDetailViewController.h"
#import "MTHMultilineTableViewCell.h"
#import "MTHNetworkHistoryViewCell.h"
#import "MTHNetworkTaskAdvice.h"
#import "MTHNetworkTaskInspectionBandwidth.h"
#import "MTHNetworkTaskInspectionScheduling.h"
#import "MTHNetworkTaskInspector.h"
#import "MTHNetworkTaskInspectorContext.h"
#import "MTHNetworkTransaction.h"
#import "MTHNetworkTransactionAdviceDetailViewModel.h"
#import "MTHNetworkTransactionDetailTableViewController.h"
#import "MTHNetworkWaterfallViewController.h"

static CGFloat const kWaterfallViewHeight = 140.f;

typedef NS_ENUM(NSInteger, MTHTransactionAdviceDetailSectionType) {
    MTHTransactionAdviceDetailSectionTypeDescription,
    MTHTransactionAdviceDetailSectionTypeWaterfall,
    MTHTransactionAdviceDetailSectionTypeTransactions,
    MTHTransactionAdviceDetailSectionTypeSuggestion,
};


@interface MTHTransactionAdviceDetailSection : NSObject

@property (nonatomic, assign) MTHTransactionAdviceDetailSectionType type;
@property (nonatomic, copy) NSString *title;

@end

@implementation MTHTransactionAdviceDetailSection

@end


@interface MTHNetworkTransactionAdviceDetailViewController () <MTHNetworkHistoryViewCellDelegate>

@property (nonatomic, copy) NSArray<MTHTransactionAdviceDetailSection *> *sections;

@property (nonatomic, copy) NSArray<MTHNetworkTransaction *> *relatedTransactions;
@property (nonatomic, copy) NSIndexSet *relatedRequestIndexes; /**< 与 relatedTransactions 相对应的 request index 集合 */

@property (nonatomic, strong) UIView *waterfallPlaceView;
@property (nonatomic, strong) MTHNetworkWaterfallViewController *waterfallViewController;
@property (nonatomic, strong) MTHNetworkTransactionAdviceDetailViewModel *viewModel;

@property (nonatomic, strong) NSIndexPath *selectedIndexPath;

@end

@implementation MTHNetworkTransactionAdviceDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = self.advice.adviceTitleText;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStyleGrouped];
    [self.tableView registerClass:[MTHMultilineTableViewCell class]
           forCellReuseIdentifier:NSStringFromClass([MTHMultilineTableViewCell class])];
    [self.tableView registerClass:[MTHNetworkHistoryViewCell class]
           forCellReuseIdentifier:NSStringFromClass([MTHNetworkHistoryViewCell class])];
    [self.tableView registerClass:[UITableViewCell class]
           forCellReuseIdentifier:NSStringFromClass([UITableViewCell class])];

    [self setupDataSource];
    [self setupWaterfall];
}

- (void)setupDataSource {
    NSMutableArray *sections = [NSMutableArray arrayWithCapacity:4];

    MTHTransactionAdviceDetailSection *descSection = [[MTHTransactionAdviceDetailSection alloc] init];
    descSection.type = MTHTransactionAdviceDetailSectionTypeDescription;
    descSection.title = @"Advice";
    [sections addObject:descSection];

    NSDictionary *userInfo = self.advice.userInfo;

    if (userInfo) {
        NSArray *relatedIndexesArray;

        if ((relatedIndexesArray = userInfo[kkMTHNetworkTaskAdviceKeyDuplicatedRequestIndexList]) && relatedIndexesArray.count) {
            // 重复请求问题
            NSMutableIndexSet *duplicatedIndexSet = [NSMutableIndexSet indexSet];
            for (NSNumber *index in relatedIndexesArray) {
                [duplicatedIndexSet addIndex:index.unsignedIntegerValue];
            }
            self.relatedRequestIndexes = duplicatedIndexSet;
            self.relatedTransactions = [[[[MTHNetworkTaskInspector shared].context transactionsForRequestIndexes:duplicatedIndexSet] reverseObjectEnumerator] allObjects];
            MTHTransactionAdviceDetailSection *transSection = [[MTHTransactionAdviceDetailSection alloc] init];
            transSection.type = MTHTransactionAdviceDetailSectionTypeTransactions;
            transSection.title = @"Transactions";
            [sections addObject:transSection];

        } else if ((relatedIndexesArray = userInfo[kMTHNetworkTaskAdviceKeyParallelRequestIndexList]) && relatedIndexesArray.count) {
            // 并行请求问题
            NSMutableIndexSet *parallelIndexSet = [NSMutableIndexSet indexSet];
            for (NSNumber *index in relatedIndexesArray) {
                [parallelIndexSet addIndex:index.unsignedIntegerValue];
            }
            self.relatedRequestIndexes = parallelIndexSet;
            self.relatedTransactions = [[[[MTHNetworkTaskInspector shared].context transactionsForRequestIndexes:parallelIndexSet] reverseObjectEnumerator] allObjects];
            MTHTransactionAdviceDetailSection *transSection = [[MTHTransactionAdviceDetailSection alloc] init];
            transSection.type = MTHTransactionAdviceDetailSectionTypeTransactions;
            transSection.title = @"Transactions";
            MTHTransactionAdviceDetailSection *waterfallSection = [[MTHTransactionAdviceDetailSection alloc] init];
            waterfallSection.type = MTHTransactionAdviceDetailSectionTypeWaterfall;
            waterfallSection.title = @"Waterfall";
            [sections addObject:waterfallSection];
            [sections addObject:transSection];
        }
    }

    MTHTransactionAdviceDetailSection *sugSection = [[MTHTransactionAdviceDetailSection alloc] init];
    sugSection.type = MTHTransactionAdviceDetailSectionTypeSuggestion;
    sugSection.title = @"Suggestion";
    [sections addObject:sugSection];

    self.sections = sections;
}

- (void)setupWaterfall {
    if (!self.relatedRequestIndexes || self.relatedRequestIndexes.count == 0) {
        return;
    }

    CGFloat width = self.view.bounds.size.width;
    CGRect waterfallFrame = CGRectMake(0, 0, width, kWaterfallViewHeight);
    self.waterfallPlaceView = [[UIView alloc] initWithFrame:waterfallFrame];
    self.waterfallPlaceView.backgroundColor = [UIColor whiteColor];

    self.viewModel = [[MTHNetworkTransactionAdviceDetailViewModel alloc] initWithRequestIndex:self.advice.requestIndex relatedRequestIndexes:self.relatedRequestIndexes];
    self.waterfallViewController = [[MTHNetworkWaterfallViewController alloc] initWithViewModel:self.viewModel];
    [self.waterfallViewController willMoveToParentViewController:self];
    [self addChildViewController:self.waterfallViewController];
    self.waterfallViewController.view.frame = self.waterfallPlaceView.bounds;
    [self.waterfallPlaceView addSubview:self.waterfallViewController.view];
    [self.waterfallViewController didMoveToParentViewController:self];

    [self.waterfallViewController reloadData];
}

- (CGSize)preferredContentSize {
    return CGSizeApplyAffineTransform([UIScreen mainScreen].bounds.size, CGAffineTransformMakeScale(1, 0.8));
}

- (NSAttributedString *)attributedStringFromString:(NSString *)string {
    NSDictionary *attributes = @{
        NSFontAttributeName : [UIFont systemFontOfSize:13],
        NSForegroundColorAttributeName : [UIColor blackColor],
    };
    NSAttributedString *attributeString = [[NSAttributedString alloc] initWithString:string ?: @"" attributes:attributes];
    return attributeString;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.sections[section].type == MTHTransactionAdviceDetailSectionTypeTransactions) {
        return self.relatedTransactions.count;
    } else {
        return 1;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    MTHTransactionAdviceDetailSection *section = self.sections[indexPath.section];

    switch (section.type) {
        case MTHTransactionAdviceDetailSectionTypeDescription: {
            cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([MTHMultilineTableViewCell class]) forIndexPath:indexPath];
            cell.textLabel.attributedText = [self attributedStringFromString:self.advice.adviceDescText];
        } break;
        case MTHTransactionAdviceDetailSectionTypeWaterfall: {
            cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([UITableViewCell class]) forIndexPath:indexPath];
            [cell.contentView addSubview:self.waterfallPlaceView];
        } break;
        case MTHTransactionAdviceDetailSectionTypeTransactions: {
            MTHNetworkHistoryViewCell *transactionCell = (MTHNetworkHistoryViewCell *)[tableView dequeueReusableCellWithIdentifier:NSStringFromClass([MTHNetworkHistoryViewCell class]) forIndexPath:indexPath];
            MTHNetworkTransaction *transaction = self.relatedTransactions[indexPath.row];
            transactionCell.transaction = transaction;
            transactionCell.advices = nil; // advices ignored here
            transactionCell.delegate = self;
            cell = transactionCell;
            // 默认选中问题所在的 transaction
            if (transaction.requestIndex == self.advice.requestIndex) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [transactionCell setHighlighted:YES animated:NO];
                });
                self.selectedIndexPath = indexPath;
            }
        } break;
        case MTHTransactionAdviceDetailSectionTypeSuggestion: {
            cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([MTHMultilineTableViewCell class]) forIndexPath:indexPath];
            cell.textLabel.attributedText = [self attributedStringFromString:self.advice.suggestDescText];
        } break;
    }
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section].title;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat height = 0.f;
    MTHTransactionAdviceDetailSection *section = self.sections[indexPath.section];

    switch (section.type) {
        case MTHTransactionAdviceDetailSectionTypeDescription: {
            NSAttributedString *attributedString = [self attributedStringFromString:self.advice.adviceDescText];
            height = [MTHMultilineTableViewCell preferredHeightWithAttributedText:attributedString inTableViewWidth:tableView.frame.size.width style:tableView.style showsAccessory:NO];
        } break;
        case MTHTransactionAdviceDetailSectionTypeWaterfall: {
            height = kWaterfallViewHeight;
        } break;
        case MTHTransactionAdviceDetailSectionTypeTransactions: {
            height = [MTHNetworkHistoryViewCell preferredCellHeight];
        } break;
        case MTHTransactionAdviceDetailSectionTypeSuggestion: {
            if (self.advice.suggestDescText.length > 0) {
                NSAttributedString *attributedString = [self attributedStringFromString:self.advice.suggestDescText];
                height = [MTHMultilineTableViewCell preferredHeightWithAttributedText:attributedString inTableViewWidth:tableView.frame.size.width style:tableView.style showsAccessory:NO];
            }
        } break;
    }

    return height;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 30;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 1;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (![indexPath isEqual:self.selectedIndexPath]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark - Cell Copying

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    return action == @selector(copy:);
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    if (action == @selector(copy:)) {
        NSString *info;
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        if ([cell isMemberOfClass:[MTHMultilineTableViewCell class]]) {
            info = cell.textLabel.text;
        } else if ([cell isMemberOfClass:[MTHNetworkHistoryViewCell class]]) {
            info = [self.relatedTransactions[indexPath.row] description];
        }
        [[UIPasteboard generalPasteboard] setString:info];
    }
}

#pragma mark - MTHNetworkHistoryViewCellDelegate

- (void)mt_networkHistoryViewCellDidTappedDetail:(MTHNetworkHistoryViewCell *)cell {
    MTHNetworkTransactionDetailTableViewController *detailVC = [[MTHNetworkTransactionDetailTableViewController alloc] init];
    detailVC.transaction = cell.transaction;
    detailVC.advices = nil; // advices ignored here.

    [self.navigationController pushViewController:detailVC animated:YES];
}

@end

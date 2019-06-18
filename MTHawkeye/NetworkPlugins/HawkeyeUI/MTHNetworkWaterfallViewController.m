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


#import "MTHNetworkWaterfallViewController.h"
#import "MTHNetworkWaterfallViewCell.h"
#import "MTHNetworkWaterfallViewCellModel.h"

#import <MTHawkeye/MTHUISkeletonUtility.h>


static NSString *const reuseIdentifier = @"NetworkWaterFlowCell";
static const CGFloat kTimeIndicatorViewHeight = 20.f;
static const CGFloat kNetworkHistoryTimelineCellHeight = 20.f;

@interface MTHNetworkWaterfallViewController () <UICollectionViewDataSource, UICollectionViewDelegate>

@property (nonatomic, copy) NSArray<MTHNetworkWaterfallViewCellModel *> *cellViewModels;

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIView *timeIndicatorView;
@property (nonatomic, strong) UILabel *leftTimeIndicatorLabel;
@property (nonatomic, strong) UILabel *middleTimeIndicatorLabel;
@property (nonatomic, strong) UILabel *rightTimeIndicatorLabel;
@property (nonatomic, strong) UIView *timeIndicatorLineView;

@end


@implementation MTHNetworkWaterfallViewController

- (instancetype)initWithViewModel:(id<MTHNetworkWaterfallDataSource>)dataSource {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        self.dataSource = dataSource;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.view addSubview:self.collectionView];
    [self.view addSubview:self.timeIndicatorView];
}

- (CGRect)safeAreaForContent {
    CGRect safeArea = self.view.bounds;
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_10_3
    if (@available(iOS 11, *)) {
        safeArea = UIEdgeInsetsInsetRect(self.view.bounds, self.view.safeAreaInsets);
    }
#endif
    return safeArea;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGRect safeArea = [self safeAreaForContent];
    CGFloat minX = CGRectGetMinX(safeArea);
    CGFloat maxX = CGRectGetMaxX(safeArea);

    CGFloat collectionViewHeight = CGRectGetHeight(self.view.bounds) - kTimeIndicatorViewHeight;
    CGRect collectionFrame = CGRectMake(minX, 0, CGRectGetWidth(safeArea), collectionViewHeight);
    self.collectionView.frame = collectionFrame;
    if ([self.collectionView.collectionViewLayout isKindOfClass:[UICollectionViewFlowLayout class]]) {
        UICollectionViewFlowLayout *flowLayout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
        if (fabs(CGRectGetWidth(self.collectionView.frame) - 20.f - flowLayout.itemSize.width) > DBL_EPSILON) {
            flowLayout.itemSize = CGSizeMake(CGRectGetWidth(self.collectionView.frame) - 20.f, kNetworkHistoryTimelineCellHeight);
            [flowLayout invalidateLayout];
        }
    }

    CGRect indicatorViewFrame = CGRectMake(20.f + minX, collectionViewHeight, maxX - 20.f - minX, kTimeIndicatorViewHeight);
    self.timeIndicatorView.frame = indicatorViewFrame;

    const CGFloat leftSpace = 5.f;
    CGRect lineFrame = CGRectMake(0, 0, CGRectGetWidth(self.timeIndicatorView.bounds) - leftSpace, 1.f / [UIScreen mainScreen].scale);
    self.timeIndicatorLineView.frame = lineFrame;

    CGFloat labelPosY = 3.f;
    CGRect leftLabelFrame = CGRectMake(0, labelPosY, 40.f, 12.f);
    CGRect rightLabelFrame = CGRectMake(CGRectGetWidth(self.timeIndicatorLineView.bounds) - 60.f - leftSpace, labelPosY, 60.f, 12.f);
    CGRect middleLabelFrame = CGRectMake(CGRectGetWidth(self.timeIndicatorLineView.bounds) / 2.f - 30.f - leftSpace, labelPosY, 60.f, 12.f);
    self.leftTimeIndicatorLabel.frame = leftLabelFrame;
    self.middleTimeIndicatorLabel.frame = middleLabelFrame;
    self.rightTimeIndicatorLabel.frame = rightLabelFrame;
}

- (void)reloadData {
    NSMutableArray *array = [NSMutableArray array];
    for (NSNumber *requestIndex in [self.dataSource currentOnViewIndexArray]) {
        MTHNetworkWaterfallViewCellModel *vm = [[MTHNetworkWaterfallViewCellModel alloc] init];
        vm.timelineStartAt = [self.dataSource timelineStartAt];
        vm.timelineDuration = [self.dataSource timelineDuration];
        vm.transaction = [self.dataSource transactionFromRequestIndex:requestIndex.integerValue];
        vm.focusedTransaction = [self.dataSource transactionFromRequestIndex:[self.dataSource requestIndexFocusOnCurrently]];
        [array addObject:vm];
    }
    self.cellViewModels = [array.reverseObjectEnumerator allObjects];

    self.leftTimeIndicatorLabel.hidden = NO;
    self.middleTimeIndicatorLabel.hidden = NO;
    self.rightTimeIndicatorLabel.hidden = NO;
    CGFloat duration = [self.dataSource timelineDuration];
    if ([self.dataSource timelineDuration] > 0) {
        self.leftTimeIndicatorLabel.text = [NSString stringWithFormat:@"+0ms"];
        self.middleTimeIndicatorLabel.text = [NSString stringWithFormat:@"+%@", [MTHUISkeletonUtility stringFromRequestDuration:duration / 2.f]];
        self.rightTimeIndicatorLabel.text = [NSString stringWithFormat:@"+%@", [MTHUISkeletonUtility stringFromRequestDuration:duration]];
    } else {
        self.middleTimeIndicatorLabel.text = [NSString stringWithFormat:@"+0ms"];
        self.leftTimeIndicatorLabel.hidden = YES;
        self.rightTimeIndicatorLabel.hidden = YES;
    }

    [UIView performWithoutAnimation:^{
        [self updateContentInset];

        [self.collectionView reloadData];
    }];

    NSUInteger fixFocusIndex = [[self.dataSource currentOnViewIndexArray] indexOfObject:@([self.dataSource requestIndexFocusOnCurrently])];
    if (fixFocusIndex != NSNotFound && self.cellViewModels.count > 0) {
        fixFocusIndex = [self.dataSource currentOnViewIndexArray].count - 1 - fixFocusIndex;
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:fixFocusIndex inSection:0];
        [self.collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:YES];
    }
}

- (void)updateContentInset {
    CGFloat contentHeight = kNetworkHistoryTimelineCellHeight * self.cellViewModels.count;
    CGFloat maxStaticCollectionHeight = self.view.bounds.size.height - kTimeIndicatorViewHeight - 15.f * 2;
    if (contentHeight < maxStaticCollectionHeight) {
        CGFloat margin = floor((maxStaticCollectionHeight - contentHeight + 15.f * 2) / 2.f);
        UIEdgeInsets insets = UIEdgeInsetsMake(margin, 10.f, margin, 10.f);
        self.collectionView.contentInset = insets;
        self.collectionView.scrollIndicatorInsets = insets;
    } else {
        UIEdgeInsets insets = UIEdgeInsetsMake(15.f, 10.f, 15.f, 10.f);
        self.collectionView.contentInset = insets;
        self.collectionView.scrollIndicatorInsets = insets;
    }
}

#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.cellViewModels.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    MTHNetworkWaterfallViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    if (indexPath.row < self.cellViewModels.count) {
        cell.viewModel = self.cellViewModels[indexPath.row];
    }

    return cell;
}

// MARK: - getters
- (UICollectionView *)collectionView {
    if (_collectionView == nil) {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];

        layout.itemSize = CGSizeMake([UIScreen mainScreen].bounds.size.width - 20.f, kNetworkHistoryTimelineCellHeight);
        layout.sectionInset = UIEdgeInsetsZero;
        layout.minimumLineSpacing = 0.f;
        layout.minimumInteritemSpacing = 0.f;

        CGFloat collectionViewHeight = self.view.bounds.size.height - kTimeIndicatorViewHeight;
        CGRect collectionFrame = CGRectMake(0, 0, self.view.bounds.size.width, collectionViewHeight);

        _collectionView = [[UICollectionView alloc] initWithFrame:collectionFrame collectionViewLayout:layout];
        _collectionView.backgroundColor = [UIColor whiteColor];
        _collectionView.contentInset = UIEdgeInsetsMake(15.f, 10.f, 15.f, 10.f);
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        [_collectionView registerClass:[MTHNetworkWaterfallViewCell class] forCellWithReuseIdentifier:reuseIdentifier];
    }
    return _collectionView;
}

- (UIView *)timeIndicatorView {
    if (_timeIndicatorView == nil) {
        _timeIndicatorView = [[UIView alloc] init];
        [_timeIndicatorView addSubview:self.leftTimeIndicatorLabel];
        [_timeIndicatorView addSubview:self.middleTimeIndicatorLabel];
        [_timeIndicatorView addSubview:self.rightTimeIndicatorLabel];
        [_timeIndicatorView addSubview:self.timeIndicatorLineView];
    }
    return _timeIndicatorView;
}

- (UIView *)timeIndicatorLineView {
    if (_timeIndicatorLineView == nil) {
        _timeIndicatorLineView = [[UIView alloc] init];
        _timeIndicatorLineView.backgroundColor = [UIColor colorWithWhite:0.733 alpha:1];
    }
    return _timeIndicatorLineView;
}

- (UILabel *)leftTimeIndicatorLabel {
    if (_leftTimeIndicatorLabel == nil) {
        _leftTimeIndicatorLabel = [[UILabel alloc] init];
        _leftTimeIndicatorLabel.font = [UIFont systemFontOfSize:10.f];
        _leftTimeIndicatorLabel.textColor = [UIColor colorWithWhite:0.0118 alpha:1];
    }
    return _leftTimeIndicatorLabel;
}

- (UILabel *)middleTimeIndicatorLabel {
    if (_middleTimeIndicatorLabel == nil) {
        _middleTimeIndicatorLabel = [[UILabel alloc] init];
        _middleTimeIndicatorLabel.font = [UIFont systemFontOfSize:10.f];
        _middleTimeIndicatorLabel.textColor = [UIColor colorWithWhite:0.0118 alpha:1];
        _middleTimeIndicatorLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _middleTimeIndicatorLabel;
}

- (UILabel *)rightTimeIndicatorLabel {
    if (_rightTimeIndicatorLabel == nil) {
        _rightTimeIndicatorLabel = [[UILabel alloc] init];
        _rightTimeIndicatorLabel.font = [UIFont systemFontOfSize:10.f];
        _rightTimeIndicatorLabel.textColor = [UIColor colorWithWhite:0.0118 alpha:1];
        _rightTimeIndicatorLabel.textAlignment = NSTextAlignmentRight;
    }
    return _rightTimeIndicatorLabel;
}

@end

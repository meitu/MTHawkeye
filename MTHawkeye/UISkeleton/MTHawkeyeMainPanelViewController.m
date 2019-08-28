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


#import "MTHawkeyeMainPanelViewController.h"
#import "MTHawkeyeMainPanelSwitchViewController.h"
#import "MTHawkeyeSettingUIEntity.h"
#import "MTHawkeyeSettingViewController.h"
#import "MTHawkeyeUIClient.h"
#import "MTHawkeyeUserDefaults+UISkeleton.h"
#import "UIColor+MTHawkeye.h"


@interface MTHawkeyeUIClient (private_declare)

@property (nonatomic, strong) MTHawkeyeSettingUIEntity *settingPlugins;

@end

@interface MTHawkeyeMainPanelTitleView : UIControl

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *pointingView;

@end

@implementation MTHawkeyeMainPanelTitleView

- (instancetype)init {
    if ((self = [super init])) {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont systemFontOfSize:17];
        _titleLabel.textColor = [UIColor mth_dynamicComplementaryColor:[UIColor colorWithRed:0.0118 green:0.0118 blue:0.0118 alpha:1]];

        _pointingView = [[UILabel alloc] init];
        _pointingView.font = [UIFont systemFontOfSize:17];
        _pointingView.textColor = [UIColor mth_dynamicComplementaryColor:[UIColor colorWithRed:0.0118 green:0.0118 blue:0.0118 alpha:1]];
        _pointingView.text = @"▾";
        [_pointingView sizeToFit];

        [self addSubview:_titleLabel];
        [self addSubview:_pointingView];
    }
    return self;
}

- (void)configureTitleText:(NSString *)title {
    self.titleLabel.text = title;
    [self.titleLabel sizeToFit];

    CGRect bounds = self.titleLabel.bounds;
    bounds.size.width += (5 + self.pointingView.bounds.size.width);
    self.bounds = bounds;

    CGRect pointingViewFrame = self.pointingView.bounds;
    pointingViewFrame.origin.x = bounds.size.width - pointingViewFrame.size.width;
    pointingViewFrame.origin.y = ceil((bounds.size.height - pointingViewFrame.size.height) / 2.f);
    self.pointingView.frame = pointingViewFrame;
}

- (void)rotatePointingToUp {
    [UIView animateWithDuration:.0f
                     animations:^{
                         self.pointingView.transform = CGAffineTransformMakeRotation(M_PI);
                     }];
}

- (void)rotatePointingToDown {
    [UIView animateWithDuration:.0f
                     animations:^{
                         self.pointingView.transform = CGAffineTransformMakeRotation(0);
                     }];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    CGFloat margin = 10.f;
    CGRect area = CGRectInset(self.bounds, -margin, -margin);
    return CGRectContainsPoint(area, point);
}

@end


// MARK: -

static NSString *const kPreSelKey = @"com.meitu.hawkeye.pre-select-panel-indexpath";


@interface MTHawkeyeMainPanelViewController () <MTHawkeyeMainPanelSwitcherDelegate>

@property (nonatomic, strong) NSIndexPath *selectedIndexPath;

@property (nonatomic, strong) MTHawkeyeMainPanelTitleView *customTitleView;

@property (nonatomic, strong) UIView *childVCPlaceView;
@property (nonatomic, strong) UIViewController *currentChildVC;

@property (nonatomic, strong) UIView *switcherBackgroundView;
@property (nonatomic, strong) UIView *switcherVCPlaceView;
@property (nonatomic, strong) MTHawkeyeMainPanelSwitchViewController *switcherVC;
@property (nonatomic, assign) BOOL switcherExpended;
@property (nonatomic, assign) BOOL switcherAnimationCompleted;

@property (nonatomic, strong) UIBarButtonItem *cachedRightBarButtonItem;

@end

@implementation MTHawkeyeMainPanelViewController

- (instancetype)initWithSelectedIndexPath:(NSIndexPath *)indexPath
                               datasource:(id<MTHawkeyeMainPanelViewControllerDatasource>)datasource
                                 delegate:(id<MTHawkeyeMainPanelSwitcherDelegate>)delegate {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        self.selectedIndexPath = [NSIndexPath indexPathForRow:-1 inSection:-1];
        if (indexPath.section >= 0 && indexPath.row >= 0) {
            self.selectedIndexPath = indexPath;
        } else {
            NSString *preSelPanelIndexPath = [[MTHawkeyeUserDefaults shared] objectForKey:kPreSelKey];
            if (preSelPanelIndexPath) {
                NSArray *items = [preSelPanelIndexPath componentsSeparatedByString:@"-"];
                if (items.count == 2) {
                    NSInteger section = [items[0] integerValue];
                    NSInteger row = [items[1] integerValue];
                    self.selectedIndexPath = [NSIndexPath indexPathForRow:row inSection:section];
                }
            }
        }
        self.datasource = datasource;
        self.delegate = delegate;
    }
    return self;
}

- (instancetype)initWithSelectedPanelID:(NSString *)panelID
                             datasource:(id<MTHawkeyeMainPanelViewControllerDatasource>)datasource
                               delegate:(id<MTHawkeyeMainPanelSwitcherDelegate>)delegate {
    NSIndexPath *indexPath = [datasource indexPathForPanelID:panelID];
    return [self initWithSelectedIndexPath:indexPath datasource:datasource delegate:delegate];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.switcherAnimationCompleted = YES;
    self.switcherExpended = NO;

    self.view.backgroundColor = [UIColor colorWithWhite:0.961 alpha:1];

    self.childVCPlaceView = [[UIView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.childVCPlaceView];

    if (self.selectedIndexPath.section == -1) {
        self.selectedIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self showPanelSwitcher];
        });
    }

    [self updateChildVCAsSelectedPanelChanged];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    self.childVCPlaceView.frame = self.view.bounds;
}

// MARK: - title & switcher
- (void)updateTitleView {
    NSString *title = [self.datasource panelViewControllerTitleForSwitcherOptionAtIndexPath:self.selectedIndexPath];
    if (title == nil) {
        title = [self.delegate switcherOptionsTitleAtIndexPath:self.selectedIndexPath];
    }
    self.title = title;

    self.customTitleView = [[MTHawkeyeMainPanelTitleView alloc] init];
    [self.customTitleView addTarget:self action:@selector(titleViewTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.customTitleView configureTitleText:self.title];
    self.navigationItem.titleView = self.customTitleView;
}

- (void)titleViewTapped {
    if (!self.switcherExpended) {
        [self showPanelSwitcher];
    } else {
        [self hidePanelSwitcher];
    }
}

- (void)panelSwitcherBackgroundTapped {
    [self hidePanelSwitcher];
}

- (void)showPanelSwitcher {
    if (!self.switcherAnimationCompleted || self.switcherVC) {
        return;
    }

    self.switcherExpended = YES;
    self.switcherAnimationCompleted = NO;

    [self makeRightBarButtonItemAsSetting];

    [self.customTitleView rotatePointingToUp];

    self.switcherVC = [[MTHawkeyeMainPanelSwitchViewController alloc] initWithSelectedIndexPath:self.selectedIndexPath delegate:self];
    [self.switcherVC willMoveToParentViewController:self];

    self.switcherBackgroundView.frame = self.view.bounds;
    self.switcherBackgroundView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.switcherBackgroundView];

    self.switcherVCPlaceView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.switcherVCPlaceView];

    self.switcherVC.view.frame = CGRectZero;
    CGFloat contentHeight = [self.switcherVC fullContentHeight];
    CGFloat maxHeight = CGRectGetHeight(self.view.bounds) - self.topLayoutGuide.length - self.bottomLayoutGuide.length;
    if (contentHeight > maxHeight - 60.f) {
        contentHeight = maxHeight - 60.f;
    }

    CGRect placeViewFrame = CGRectMake(0, 0, self.view.bounds.size.width, contentHeight);
    self.switcherVC.view.frame = placeViewFrame;
    placeViewFrame.origin.y = -contentHeight + self.topLayoutGuide.length;
    self.switcherVCPlaceView.frame = placeViewFrame;

    [self.switcherVCPlaceView addSubview:self.switcherVC.view];
    [self addChildViewController:self.switcherVC];
    [self.switcherVC didMoveToParentViewController:self];

    [UIView
        animateWithDuration:0.2f
        animations:^{
            CGRect moveTo = placeViewFrame;
            moveTo.origin.y = self.topLayoutGuide.length;
            self.switcherVCPlaceView.frame = moveTo;

            self.switcherBackgroundView.backgroundColor = [UIColor colorWithWhite:0.f alpha:0.3f];
        }
        completion:^(BOOL finished) {
            self.switcherAnimationCompleted = YES;
        }];
}

- (void)hidePanelSwitcher {
    if (!self.switcherAnimationCompleted || !self.switcherVCPlaceView) {
        return;
    }

    self.switcherExpended = NO;
    self.switcherAnimationCompleted = NO;

    [self restoreRightBarButtonItemToBeforeSetting];

    [self.customTitleView rotatePointingToDown];

    [UIView
        animateWithDuration:.15f
        animations:^{
            CGRect moveTo = self.switcherVCPlaceView.frame;
            moveTo.origin.y = -self.switcherVCPlaceView.bounds.size.height + self.topLayoutGuide.length;
            self.switcherVCPlaceView.frame = moveTo;
            self.switcherBackgroundView.backgroundColor = [UIColor clearColor];
        }
        completion:^(BOOL finished) {
            [self.switcherVCPlaceView removeFromSuperview];
            [self.switcherBackgroundView removeFromSuperview];

            [self.switcherVC removeFromParentViewController];
            self.switcherVC = nil;

            self.switcherAnimationCompleted = YES;
        }];
}

// MARK: setting

- (void)makeRightBarButtonItemAsSetting {
    self.cachedRightBarButtonItem = self.currentChildVC.navigationItem.rightBarButtonItem;
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithTitle:@"Setting" style:UIBarButtonItemStylePlain target:self action:@selector(settingTapped)];
    self.navigationItem.rightBarButtonItem = rightItem;
}

- (void)restoreRightBarButtonItemToBeforeSetting {
    self.navigationItem.rightBarButtonItem = self.cachedRightBarButtonItem;
}

- (void)settingTapped {
    MTHawkeyeSettingTableEntity *entity = [[MTHawkeyeUIClient shared].settingPlugins settingViewModelEntity];
    MTHawkeyeSettingViewController *vc = [[MTHawkeyeSettingViewController alloc] initWithTitle:@"Setting" viewModelEntity:entity];
    [self.navigationController pushViewController:vc animated:YES];
}

// MARK: - Panels

- (void)updateChildVCAsSelectedPanelChanged {
    UIViewController *childPanelVC = nil;
    if ([self.delegate respondsToSelector:@selector(panelViewControllerForSwitcherOptionAtIndexPath:)]) {
        childPanelVC = [self.datasource panelViewControllerForSwitcherOptionAtIndexPath:self.selectedIndexPath];
        if (childPanelVC == nil) {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self showPanelSwitcher];
            });
            return;
        }
    }

    [self updateTitleView];
    [self switchToViewController:childPanelVC];
}

- (void)switchToViewController:(UIViewController *)vc {
    if (![self.currentChildVC isKindOfClass:[vc class]]) {
        [self removeCurrentChildVCIfNeed];
    }

    [vc willMoveToParentViewController:self];
    vc.view.frame = self.childVCPlaceView.bounds;
    [self.childVCPlaceView addSubview:vc.view];
    vc.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addChildViewController:vc];
    [vc didMoveToParentViewController:self];

    self.navigationItem.rightBarButtonItem = vc.navigationItem.rightBarButtonItem;

    self.currentChildVC = vc;
}

- (void)removeCurrentChildVCIfNeed {
    if (self.currentChildVC) {
        [self.currentChildVC.view removeFromSuperview];
        [self.currentChildVC removeFromParentViewController];
        self.currentChildVC = nil;
    }
}

// MARK: - MTHawkeyeMainPanelSwitcherDelegate

- (NSInteger)numberOfSwitcherOptionsSection {
    return [self.delegate numberOfSwitcherOptionsSection];
}

- (NSInteger)numberOfSwitcherOptionsRowAtSection:(NSInteger)section {
    return [self.delegate numberOfSwitcherOptionsRowAtSection:section];
}

- (NSString *)switcherOptionsSectionTitleAtIndex:(NSInteger)index {
    return [self.delegate switcherOptionsSectionTitleAtIndex:index] ?: @"";
}

- (NSString *)switcherOptionsTitleAtIndexPath:(NSIndexPath *)indexPath {
    return [self.delegate switcherOptionsTitleAtIndexPath:indexPath] ?: @"";
}

- (BOOL)shouldChangeSelectStatusToNew:(NSIndexPath *)newSelectIndexPath fromOld:(NSIndexPath *)oldSelectIndexPath {
    return [self.delegate shouldChangeSelectStatusToNew:newSelectIndexPath fromOld:oldSelectIndexPath];
}

- (void)panelSwitcherDidSelectAtIndexPath:(NSIndexPath *)indexPath {
    [self.delegate panelSwitcherDidSelectAtIndexPath:indexPath];

    [self hidePanelSwitcher];

    BOOL needCacheSelectedIndex = NO;
    if (self.selectedIndexPath == indexPath) {
        // the very first run, the {0,0} will selected by default.
        if ([[[MTHawkeyeUserDefaults shared] objectForKey:kPreSelKey] length] == 0) {
            needCacheSelectedIndex = YES;
        }
    } else {
        BOOL changeSelect = [self.delegate shouldChangeSelectStatusToNew:indexPath fromOld:self.selectedIndexPath];
        if (changeSelect) {
            needCacheSelectedIndex = YES;
            self.selectedIndexPath = indexPath;
            [self updateChildVCAsSelectedPanelChanged];
        }
    }

    if (needCacheSelectedIndex) {
        NSString *value = [NSString stringWithFormat:@"%ld-%ld", (long)indexPath.section, (long)indexPath.row];
        [[MTHawkeyeUserDefaults shared] setObject:value forKey:kPreSelKey];
    }
}

// MARK: - getter
- (UIView *)switcherBackgroundView {
    if (_switcherBackgroundView == nil) {
        _switcherBackgroundView = [[UIView alloc] init];
        _switcherBackgroundView.backgroundColor = [UIColor clearColor];
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(panelSwitcherBackgroundTapped)];
        [_switcherBackgroundView addGestureRecognizer:tapGesture];
    }
    return _switcherBackgroundView;
}


@end

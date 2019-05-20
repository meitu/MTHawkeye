//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 07/06/2018
// Created by: Huni
//


#import "MTHToastView.h"
#import "MTHToastWindow.h"

#define WS(weakSelf) __weak __typeof(&*self) weakSelf = self;
#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height

static const NSTimeInterval kAnimationDuration = 0.3;
static const NSInteger kMaxButtonNumber = 2;

static NSString *const kTitleLabelCenterYConstraintIdentifier = @"kTitleLabelCenterYConstraintIdentifier";

@interface MTHToastView ()

@property (strong, nonatomic) UIView *backgroundView;
@property (strong, nonatomic) UILabel *titleLabel;
@property (strong, nonatomic) UILabel *contentLabel;

@property (assign, nonatomic) CGFloat shortContentHeight;
@property (assign, nonatomic) NSInteger leftButtonNumber;
@property (assign, nonatomic) NSInteger rightButtonNumber;

@property (assign, readonly, nonatomic) CGFloat fixedX;
@property (assign, readonly, nonatomic) CGFloat fixedY;
@property (assign, readonly, nonatomic) CGFloat fixedWidth;
@property (assign, readonly, nonatomic) CGFloat fixedHeight;
@property (assign, readonly, nonatomic) CGFloat calculatedHeight;

@property (strong, nonatomic) dispatch_source_t hideTimer;
@property (assign, nonatomic) BOOL isPauseTimer;

@property (strong, nonatomic) MTHToastViewMaker *maker;

@property (assign, nonatomic) BOOL isExpand;

@end

@implementation MTHToastView

static MTHToastWindow *sharedWindow;

#pragma mark - Public

+ (instancetype)toastViewFrom:(void (^)(MTHToastViewMaker *make))block {

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedWindow = [MTHToastWindow sharedWindow];
    });

    MTHToastViewMaker *maker = [MTHToastViewMaker new];
    block(maker);

    MTHToastView *toastView = [[MTHToastView alloc] initViewWithConstarints];
    toastView.userInteractionEnabled = YES;
    [toastView mth_addGestureRecognizer];
    toastView.maker = maker;

    return toastView;
}

- (instancetype)initViewWithConstarints {
    (self = [super init]);
    if (self) {
        [self makeBackgroundViewConstraints];
        [self makeTitleLabelConstraints];
        [self makeContentLabelConstraints];
    }
    return self;
}


- (void)showToastView {

    self.backgroundColor = [UIColor clearColor];
    [self showToastViewWithMakerStyle];

    [sharedWindow.rootViewController.view addSubview:self];

    self.frame = CGRectMake(self.fixedX, -self.fixedHeight, self.fixedWidth, self.fixedHeight);

    WS(weakSelf);

    [UIView animateWithDuration:kAnimationDuration
        delay:0.0
        options:UIViewAnimationOptionCurveEaseIn
        animations:^{
            self.frame = CGRectMake(self.fixedX, self.fixedY, self.fixedWidth, self.fixedHeight);
        }
        completion:^(BOOL finished) {
            if (!self.isPauseTimer) {
                [weakSelf startTimer];
            }
        }];
}

- (void)showToastViewWithMakerStyle {

    switch (self.maker.style) {
        case MTHToastViewStyleDetail: {
            self.contentLabel.hidden = NO;
            self.titleLabel.text = self.maker.title;
            self.titleLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14.0];
            self.titleLabel.numberOfLines = 1;
            self.contentLabel.text = self.maker.shortContent;
            self.shortContentHeight = CGRectGetHeight(self.contentLabel.frame);
        } break;
        case MTHToastViewStyleSimple: {
            self.contentLabel.hidden = YES;
            self.titleLabel.text = self.maker.title;
            self.titleLabel.numberOfLines = 0;
            self.titleLabel.font = [UIFont systemFontOfSize:16.0];
            self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

            for (NSLayoutConstraint *constraint in self.backgroundView.constraints) {
                if ([constraint.identifier isEqualToString:kTitleLabelCenterYConstraintIdentifier]) {
                    [self.backgroundView removeConstraint:constraint];
                }
            }

            NSLayoutConstraint *topContraint = [NSLayoutConstraint constraintWithItem:self.titleLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.backgroundView attribute:NSLayoutAttributeTop multiplier:1.0 constant:12];

            [self.backgroundView addConstraints:@[ topContraint ]];
        } break;
        default:
            break;
    }
}

- (void)hideToastView {
    for (UIView *subView in self.subviews) {
        if ([subView isKindOfClass:UIButton.class]) {
            [subView removeFromSuperview];
        }
    }
    [self mth_hideToastView];
}


- (void)setupLeftButtonWithTitle:(NSString *)title
                        andEvent:(MTHToastButtonActionBlock)event {

    if (self.leftButtonNumber == kMaxButtonNumber) {
        return;
    }
    UIButton *leftButton = [[UIButton alloc] init];
    [leftButton setTitle:title forState:UIControlStateNormal];
    leftButton.titleLabel.font = [UIFont systemFontOfSize:12.0];
    [leftButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [leftButton setTintColor:[UIColor whiteColor]];
    leftButton.hidden = YES;
    [self addSubview:leftButton];

    [leftButton setTranslatesAutoresizingMaskIntoConstraints:NO];

    NSLayoutConstraint *leftContraint = [NSLayoutConstraint constraintWithItem:leftButton attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1.0 constant:24.0 + self.leftButtonNumber * 55];

    NSLayoutConstraint *bottomContraint = [NSLayoutConstraint constraintWithItem:leftButton attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1.0 constant:-10.0];

    NSArray *array = [NSArray arrayWithObjects:leftContraint, bottomContraint, nil];
    [self addConstraints:array];

    [leftButton mth_handleControlEvent:UIControlEventTouchUpInside
                             withBlock:event];
    self.contentLabel.text = self.maker.shortContent;
    self.leftButtonNumber += 1;
}

- (void)setupRightButtonWithTitle:(NSString *)title
                         andEvent:(MTHToastButtonActionBlock)event {

    if (self.rightButtonNumber == kMaxButtonNumber) {
        return;
    }
    UIButton *rightButton = [[UIButton alloc] init];
    [rightButton setTitle:title forState:UIControlStateNormal];
    rightButton.titleLabel.font = [UIFont systemFontOfSize:16.0];
    [rightButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    rightButton.hidden = YES;
    [self addSubview:rightButton];

    [rightButton setTranslatesAutoresizingMaskIntoConstraints:NO];

    NSLayoutConstraint *rightContraint = [NSLayoutConstraint constraintWithItem:rightButton attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1.0 constant:-24.0 - self.rightButtonNumber * 55];

    NSLayoutConstraint *bottomContraint = [NSLayoutConstraint constraintWithItem:rightButton attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1.0 constant:-10.0];

    NSArray *array = [NSArray arrayWithObjects:rightContraint, bottomContraint, nil];
    [self addConstraints:array];

    [rightButton mth_handleControlEvent:UIControlEventTouchUpInside
                              withBlock:event];
    self.contentLabel.text = self.maker.shortContent;
    self.rightButtonNumber += 1;
}

- (void)pauseTimer {
    [self releaseTimer];
    self.isPauseTimer = YES;
}

- (void)releaseTimer {
    @synchronized(self.hideTimer) {
        if (self.hideTimer) {
            dispatch_cancel(self.hideTimer);
            self.hideTimer = nil;
        }
    }
}

- (void)startTimer {
    [self releaseTimer];

    WS(weakSelf);
    __block float stayDuration = self.maker.stayDuration;
    self.hideTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(0, 0));
    dispatch_source_set_timer(self.hideTimer, dispatch_walltime(NULL, 0), 1.0 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(self.hideTimer, ^{
        @autoreleasepool {
            if (stayDuration <= 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf mth_hideToastView];
                });
            } else {
                stayDuration--;
            }
        }
    });
    dispatch_resume(self.hideTimer);
}

#pragma mark - Constraints

- (void)makeBackgroundViewConstraints {
    self.backgroundView = [[UIView alloc] init];
    self.backgroundView.layer.cornerRadius = 8;
    self.backgroundView.layer.masksToBounds = YES;
    [self addSubview:self.backgroundView];

    [self.backgroundView setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSLayoutConstraint *leftContraint = [NSLayoutConstraint constraintWithItem:self.backgroundView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1.0 constant:8.0];
    NSLayoutConstraint *topContraint = [NSLayoutConstraint constraintWithItem:self.backgroundView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1.0 constant:8.0];
    NSLayoutConstraint *rightContraint = [NSLayoutConstraint constraintWithItem:self.backgroundView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1.0 constant:-8.0];
    NSLayoutConstraint *bottomContraint = [NSLayoutConstraint constraintWithItem:self.backgroundView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1.0 constant:-8.0];
    [self addConstraints:@[ leftContraint, topContraint, rightContraint, bottomContraint ]];

    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    [self.backgroundView addSubview:effectView];

    [effectView setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSLayoutConstraint *leftEffectContraint = [NSLayoutConstraint constraintWithItem:effectView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.backgroundView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0];
    NSLayoutConstraint *topEffectContraint = [NSLayoutConstraint constraintWithItem:effectView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.backgroundView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0];
    NSLayoutConstraint *rightEffectContraint = [NSLayoutConstraint constraintWithItem:effectView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.backgroundView attribute:NSLayoutAttributeRight multiplier:1.0 constant:0];
    NSLayoutConstraint *bottomEffectContraint = [NSLayoutConstraint constraintWithItem:effectView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.backgroundView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0];

    [self addConstraints:@[ leftEffectContraint, topEffectContraint, rightEffectContraint, bottomEffectContraint ]];
}

- (void)makeTitleLabelConstraints {
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont systemFontOfSize:14.0];
    self.titleLabel.textColor = [UIColor whiteColor];
    [self.backgroundView addSubview:self.titleLabel];

    [self.titleLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSLayoutConstraint *leftContraint = [NSLayoutConstraint constraintWithItem:self.titleLabel attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.backgroundView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:16.0];
    NSLayoutConstraint *rightContraint = [NSLayoutConstraint constraintWithItem:self.titleLabel attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.backgroundView attribute:NSLayoutAttributeRight multiplier:1.0 constant:-16.0];
    NSLayoutConstraint *topContraint = [NSLayoutConstraint constraintWithItem:self.titleLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.backgroundView attribute:NSLayoutAttributeTop multiplier:1.0 constant:12.0];
    topContraint.identifier = kTitleLabelCenterYConstraintIdentifier;
    [self.backgroundView addConstraints:@[ leftContraint, rightContraint, topContraint ]];
}

- (void)makeContentLabelConstraints {
    self.contentLabel = [[UILabel alloc] init];
    self.contentLabel.font = [UIFont systemFontOfSize:14.0];
    self.contentLabel.textColor = [UIColor whiteColor];
    self.contentLabel.numberOfLines = 0;
    [self.backgroundView addSubview:self.contentLabel];

    [self.contentLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSLayoutConstraint *leftContraint = [NSLayoutConstraint constraintWithItem:self.contentLabel attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.titleLabel attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0];
    NSLayoutConstraint *rightContraint = [NSLayoutConstraint constraintWithItem:self.contentLabel attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.backgroundView attribute:NSLayoutAttributeRight multiplier:1.0 constant:-16.0];
    NSLayoutConstraint *topContraint = [NSLayoutConstraint constraintWithItem:self.contentLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.titleLabel attribute:NSLayoutAttributeBottom multiplier:1.0 constant:8.0];
    [self.backgroundView addConstraints:@[ leftContraint, rightContraint, topContraint ]];
}


#pragma mark - Property
- (NSInteger)leftButtonNumber {
    if (!_leftButtonNumber) {
        _leftButtonNumber = 0;
    }
    return _leftButtonNumber;
}
- (NSInteger)rightButtonNumber {
    if (!_rightButtonNumber) {
        _rightButtonNumber = 0;
    }
    return _rightButtonNumber;
}

- (CGFloat)fixedX {
    return ([self isiPhoneX] && ![self isPortrait]) ? 128.0 : (self.maker.style == MTHToastViewStyleDetail ? 0 : (kScreenWidth - [self calculatedWidth]) / 2);
}

- (CGFloat)fixedY {
    return ([self isiPhoneX] && [self isPortrait]) ? 33.0 : 10;
}

- (CGFloat)fixedHeight {
    return [self calculatFixedHeight];
}

- (CGFloat)calculatFixedHeight {
    if (self.maker.style == MTHToastViewStyleSimple) {
        self.titleLabel.text = self.maker.title;
        CGSize labelsize = [self.titleLabel sizeThatFits:CGSizeMake(kScreenWidth - 48, CGFLOAT_MAX)];
        return labelsize.height + 40;
    } else {
        self.contentLabel.text = self.maker.shortContent;
        CGSize labelsize = [self.contentLabel sizeThatFits:CGSizeMake(kScreenWidth - 48, CGFLOAT_MAX)];
        return labelsize.height + 66;
    }
}

- (CGFloat)fixedWidth {
    return ([self isiPhoneX] && ![self isPortrait]) ? 556.0 : (self.maker.style == MTHToastViewStyleDetail ? kScreenWidth : [self calculatedWidth]);
}

- (CGFloat)calculatedWidth {
    self.titleLabel.text = self.maker.title;
    CGSize size = [self.titleLabel.text sizeWithAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIFont systemFontOfSize:16.0], NSFontAttributeName, nil]];
    return size.width + 56 > kScreenWidth ? kScreenWidth : size.width + 56;
}

- (CGFloat)calculatedHeight {
    self.contentLabel.text = self.maker.longContent;
    CGSize size = CGSizeMake(self.contentLabel.frame.size.width, MAXFLOAT);
    NSDictionary *dict = [NSDictionary dictionaryWithObject:[UIFont systemFontOfSize:self.contentLabel.font.pointSize] forKey:NSFontAttributeName];
    CGFloat calculatedHeight = [self.contentLabel.text boundingRectWithSize:size options:NSStringDrawingUsesLineFragmentOrigin attributes:dict context:nil].size.height;
    return calculatedHeight;
}

- (BOOL)isPortrait {
    return kScreenWidth < kScreenHeight;
}

- (BOOL)isiPhoneX {
    static BOOL isiPhoneX = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGSize size = UIScreen.mainScreen.bounds.size;
        isiPhoneX = MAX(size.width, size.height) == 812.0;
    });
    return isiPhoneX;
}

#pragma mark - Private

- (void)mth_addGestureRecognizer {
    UISwipeGestureRecognizer *swipeUpGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(mth_swipeUpGesture:)];
    swipeUpGesture.direction = UISwipeGestureRecognizerDirectionUp;
    [self addGestureRecognizer:swipeUpGesture];

    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(mth_tapGesture:)];
    [self addGestureRecognizer:tapGesture];

    UISwipeGestureRecognizer *swipeDownGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(mth_swipeDownGesture:)];
    swipeDownGesture.direction = UISwipeGestureRecognizerDirectionDown;
    [self addGestureRecognizer:swipeDownGesture];
}

- (void)mth_swipeUpGesture:(UISwipeGestureRecognizer *)gesture {
    if (gesture.direction == UISwipeGestureRecognizerDirectionUp && !self.isExpand) {
        [self releaseTimer];
        for (UIView *subView in self.subviews) {
            if ([subView isKindOfClass:UIButton.class]) {
                [subView removeFromSuperview];
            }
        }
        [self mth_hideToastView];
    }
}

- (void)mth_tapGesture:(UITapGestureRecognizer *)tapGesture {
    if (self.maker.style == MTHToastViewStyleSimple) {
        if (self.clickedBlock) {
            self.clickedBlock();
        }
    } else {
        [self mth_expandToastView];
    }
}

- (void)mth_swipeDownGesture:(UISwipeGestureRecognizer *)gesture {
    if (self.maker.style == MTHToastViewStyleSimple) {
        return;
    }
    if (gesture.direction == UISwipeGestureRecognizerDirectionDown) {
        [self mth_expandToastView];
    }
}

- (void)mth_hideToastView {
    [UIView animateWithDuration:kAnimationDuration
        delay:0.0
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
            if (self.isExpand) {
                CGFloat expandHeight = (self.fixedHeight + self.calculatedHeight - self.shortContentHeight + 10 < kScreenHeight - 16) ? (self.fixedHeight + self.calculatedHeight - self.shortContentHeight + 10) : (kScreenHeight - 16);
                self.frame = CGRectMake(self.fixedX, -expandHeight, self.fixedWidth, expandHeight);
            } else {
                self.frame = CGRectMake(self.fixedX, -self.fixedHeight, self.fixedWidth, self.fixedHeight);
            }
        }
        completion:^(BOOL finished) {
            [self removeFromSuperview];
            if (self.hiddenBlock) {
                self.hiddenBlock();
            }
        }];
}

- (void)mth_expandToastView {

    self.isExpand = YES;
    if (!self.maker.expendHidden) {
        [self releaseTimer];
    }
    for (UIView *subView in self.subviews) {
        subView.hidden = NO;
    }
    CGFloat expandHeight = (self.fixedHeight + self.calculatedHeight - self.shortContentHeight + 10 < kScreenHeight - 16) ? (self.fixedHeight + self.calculatedHeight - self.shortContentHeight + 10) : (kScreenHeight - 16);
    if (fabs(expandHeight - (kScreenHeight - 16)) < FLT_EPSILON) {
        NSLayoutConstraint *bottomContraint = [NSLayoutConstraint constraintWithItem:self.contentLabel attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1.0 constant:-38.0];
        [self addConstraint:bottomContraint];
    }
    [UIView animateWithDuration:kAnimationDuration
        delay:0.0
        options:UIViewAnimationOptionCurveEaseIn
        animations:^{
            self.frame = CGRectMake(self.fixedX, self.fixedY, self.fixedWidth, expandHeight);
        }
        completion:^(BOOL finished) {
            self.frame = CGRectMake(self.fixedX, self.fixedY, self.fixedWidth, expandHeight);
        }];
}

@end

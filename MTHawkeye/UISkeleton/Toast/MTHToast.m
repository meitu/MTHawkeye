//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 13/06/2018
// Created by: Huni
//


#import "MTHToast.h"
#import "MTHToastView.h"

@interface MTHToast ()
@property (strong, nonatomic) NSMutableArray<MTHToastView *> *toastViews;
@end

@implementation MTHToast

+ (instancetype)shared {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _toastViews = [NSMutableArray array];
    }
    return self;
}

- (void)showToastWithMessage:(NSString *)message
                     handler:(void (^)(void))handler {
    [self showToastWithStyle:MTHToastStyleSimple
                       title:nil
                     content:message
               detailContent:nil
                    duration:0
                     handler:handler
              buttonHandlers:nil
        autoHiddenBeOccluded:NO];
}

- (void)showToastWithStyle:(MTHToastStyle)style
                     title:(NSString *)title
                   content:(NSString *)content
             detailContent:(NSString *)detailContent
                  duration:(NSTimeInterval)duration
                   handler:(void (^)(void))handler
            buttonHandlers:(NSArray<MTHToastBtnHandler *> *)buttonHandlers
      autoHiddenBeOccluded:(BOOL)hidden {

    MTHToastView *toastView = nil;
    __weak typeof(self) weakSelf = self;
    switch (style) {
        case MTHToastStyleSimple: {
            toastView = [MTHToastView toastViewFrom:^(MTHToastViewMaker *make) {
                make.style = MTHToastViewStyleSimple;
                make.title = content;
                make.stayDuration = duration;
            }];

            __weak MTHToastView *weakToast = toastView;
            toastView.clickedBlock = ^{
                if (handler) {
                    handler();
                }
                [weakToast hideToastView];
            };
            break;
        }

        case MTHToastStyleDetail: {
            toastView = [MTHToastView toastViewFrom:^(MTHToastViewMaker *make) {
                make.style = MTHToastViewStyleDetail;
                make.title = title;
                make.shortContent = content;
                make.longContent = detailContent;
                make.expendHidden = hidden;
                make.stayDuration = duration;
            }];

            __weak MTHToastView *weakToast = toastView;
            MTHToastButtonActionBlock defaultEvent = ^{
                [weakToast hideToastView];
            };
            [toastView setupRightButtonWithTitle:@"YES" andEvent:defaultEvent];

            for (MTHToastBtnHandler *btnHandler in buttonHandlers) {
                MTHToastButtonActionBlock btnEvent = ^{
                    if (btnHandler.handler) {
                        btnHandler.handler();
                    }
                };

                if (btnHandler.style == MTHToastActionStyleLeft) {
                    [toastView setupLeftButtonWithTitle:btnHandler.title andEvent:btnEvent];
                } else {
                    [toastView setupRightButtonWithTitle:btnHandler.title andEvent:btnEvent];
                }
            }
            break;
        }
        default:
            break;
    }

    toastView.hiddenBlock = ^{
        if (hidden) {
            return;
        }
        [weakSelf.toastViews removeLastObject];
        [weakSelf mth_pauseUntreatedToastView];
        MTHToastView *lastToast = [weakSelf.toastViews lastObject];
        [lastToast startTimer];
    };

    if (!hidden) {
        [self.toastViews addObject:toastView];
        [self mth_pauseUntreatedToastView];
    }

    [toastView showToastView];
}

#pragma mark - Internal
- (void)mth_pauseUntreatedToastView {
    if (self.toastViews.count < 1) {
        return;
    }

    [self.toastViews enumerateObjectsUsingBlock:^(MTHToastView *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        if (idx == self.toastViews.count - 1) {
            *stop = YES;
            return;
        }
        [obj pauseTimer];
    }];
}

@end

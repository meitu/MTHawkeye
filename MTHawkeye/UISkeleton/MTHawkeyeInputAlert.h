//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/18
// Created by: EuanC
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTHawkeyeInputAlert : NSObject

+ (void)showInputAlertWithTitle:(nullable NSString *)title
                       messgage:(nullable NSString *)message
                           from:(UIViewController *)fromVC
          textFieldSetupHandler:(void (^)(UITextField *textField))setupHandler
                 confirmHandler:(void (^)(UITextField *textField))confirmHandler
                  cancelHandler:(nullable void (^)(UITextField *textField))cancelHandler;

@end

NS_ASSUME_NONNULL_END

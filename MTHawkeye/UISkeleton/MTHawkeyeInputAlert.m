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


#import "MTHawkeyeInputAlert.h"

@implementation MTHawkeyeInputAlert

+ (void)showInputAlertWithTitle:(NSString *)title
                       messgage:(NSString *)message
                           from:(UIViewController *)fromVC
          textFieldSetupHandler:(void (^)(UITextField *textField))setupHandler
                 confirmHandler:(void (^)(UITextField *textField))confirmHandler
                  cancelHandler:(void (^)(UITextField *textField))cancelHandler {
    // 临时开启 MTHFloatingMonitorWindow 的 allowBecomingKeyWindow，暂时解决 iOS 11 下，非 Key Window 不能弹出键盘的问题
    // 稍后在 AlertView 消失时，关闭 allowBecomingKeyWindow。
    UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MTHPermissionToBecomeKeyWindowChanged"
                                                        object:nil
                                                      userInfo:@{@"MTHAllowToBecomeKeyWindow" : @YES}];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
        if (setupHandler)
            setupHandler(textField);
    }];

    // 收起 AlertView 后，关闭 MTHFloatingMonitorWindow 的 allowBecomingKeyWindow
    // 恢复之前 Key Window
    void (^ResignHawkeyeKeyWindow)(void) = ^void(void) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MTHPermissionToBecomeKeyWindowChanged" object:nil userInfo:@{@"MTHAllowToBecomeKeyWindow" : @NO}];
        [mainWindow makeKeyWindow];
    };

    __weak typeof(alert) weak_alert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"Confirm"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *_Nonnull action) {
                                                if (confirmHandler) {
                                                    confirmHandler(weak_alert.textFields.lastObject);
                                                }
                                                ResignHawkeyeKeyWindow();
                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *_Nonnull action) {
                                                if (cancelHandler) {
                                                    cancelHandler(weak_alert.textFields.lastObject);
                                                }

                                                ResignHawkeyeKeyWindow();
                                            }]];
    [fromVC presentViewController:alert animated:YES completion:nil];
}

@end

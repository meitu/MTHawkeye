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

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
        if (setupHandler)
            setupHandler(textField);
    }];

    __weak typeof(alert) weak_alert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"Confirm"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *_Nonnull action) {
                                                if (confirmHandler) {
                                                    confirmHandler(weak_alert.textFields.lastObject);
                                                }
                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *_Nonnull action) {
                                                if (cancelHandler) {
                                                    cancelHandler(weak_alert.textFields.lastObject);
                                                }
                                            }]];
    [fromVC presentViewController:alert animated:YES completion:nil];
}

@end

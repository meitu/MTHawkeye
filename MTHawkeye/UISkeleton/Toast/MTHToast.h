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


#import <Foundation/Foundation.h>
#import "MTHToastBtnHandler.h"

typedef NS_ENUM(NSInteger, MTHToastStyle) {
    MTHToastStyleSimple = 0,
    MTHToastStyleDetail
};


@interface MTHToast : NSObject

+ (instancetype)shared;


/**
 显示短消息的弹框

 @param message 信息
 @param handler 点击弹框时间，默认为收起弹框
 */
- (void)showToastWithMessage:(NSString *)message
                     handler:(void (^)(void))handler;

/**
 显示 Toast 弹框

 @param style 弹框类型
 @param title 弹框标题
 @param content 弹框内容
 @param detailContent 弹框展开后内容
 @param duration 弹框持续时间
 @param handler 点击弹框事件
 @param buttonHandlers 弹框展开后添加的按钮
 @param hidden 弹框被遮挡后是否要被忽略
 */
- (void)showToastWithStyle:(MTHToastStyle)style
                     title:(NSString *)title
                   content:(NSString *)content
             detailContent:(NSString *)detailContent
                  duration:(NSTimeInterval)duration
                   handler:(void (^)(void))handler
            buttonHandlers:(NSArray<MTHToastBtnHandler *> *)buttonHandlers
      autoHiddenBeOccluded:(BOOL)hidden;

@end

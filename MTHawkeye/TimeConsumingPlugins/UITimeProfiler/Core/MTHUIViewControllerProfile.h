//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/6/4
// Created by: 潘名扬
//


#import <UIKit/UIKit.h>


@interface MTHFakeKVOObserver : NSObject
@end


#pragma mark -

@interface MTHFakeKVORemover : NSObject

@property (nonatomic, unsafe_unretained) id target;
@property (nonatomic, copy) NSString *keyPath;

@end


#pragma mark -

@interface MTHUIViewControllerProfile : NSObject

+ (void)startVCProfile;

@end

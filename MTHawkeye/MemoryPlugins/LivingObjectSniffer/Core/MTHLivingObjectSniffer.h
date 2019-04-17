//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/6
// Created by: EuanC
//


#import <Foundation/Foundation.h>
#import "MTHLivingObjectInfo.h"
#import "MTHLivingObjectShadow.h"

NS_ASSUME_NONNULL_BEGIN

@interface MTHLivingObjectShadowPackageInspectResultItem : NSObject

@property (nonatomic, strong) MTHLivingObjectGroupInClass *theGroupInClass;
@property (nonatomic, copy) NSArray<MTHLivingObjectInfo *> *livingObjectsNew;

@end


@interface MTHLivingObjectShadowPackageInspectResult : NSObject

@property (nonatomic, copy) NSArray<MTHLivingObjectShadowPackageInspectResultItem *> *items;
@property (nonatomic, strong) MTHLivingObjectShadowTrigger *trigger;

@end



/****************************************************************************/
#pragma mark -



@protocol MTHLivingObjectSnifferDelegate;

@interface MTHLivingObjectSniffer : NSObject

@property (nonatomic, readonly, nullable) NSArray<MTHLivingObjectGroupInClass *> *livingObjectGroupsInClass;
@property (nonatomic, strong) NSMutableArray<NSString *> *ignoreList;

- (instancetype)init;

- (void)addDelegate:(id<MTHLivingObjectSnifferDelegate>)delegate;
- (void)removeDelegate:(id<MTHLivingObjectSnifferDelegate>)delegate;

/**
 All the shadows in shadowPackage are expected to all released after `delayInSeconds`.
 */
- (void)sniffWillReleasedLivingObjectShadowPackage:(MTHLivingObjectShadowPackage *)shadowPackage
                                  expectReleasedIn:(NSTimeInterval)delayInSeconds
                                       triggerInfo:(MTHLivingObjectShadowTrigger *)trigger;

- (void)sniffLivingViewShadow:(MTHLivingObjectShadow *)shadow;

@end


@protocol MTHLivingObjectSnifferDelegate <NSObject>

@required
- (void)livingObjectSniffer:(MTHLivingObjectSniffer *)sniffer
          didSniffOutResult:(MTHLivingObjectShadowPackageInspectResult *)result;

@end

NS_ASSUME_NONNULL_END

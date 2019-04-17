//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/11/20
// Created by: EuanC
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 The result of symbolics service.

 @param mallocReport Symbolicated malloc report, it will used to display on the next screen.
 @param vmReport Symbolicated vm report, it will used to display on the next screen.
 @param error Symbolics process error.
 */
typedef void (^MTHAllocationsReportSymbolicsCompletion)(NSString *mallocReport, NSString *vmReport, NSError *error);

/**
 Implement your own symbolics service completely.

 @param mallocReportInJson The original malloc report in json style, the stack record inside need symbolicated.
 @param vmReportInJson The original vm report in json style, the stack record inside need symbolicated.
 @param dyldImagesInfoInJson The necessary dyld images info for symbolicate.
 @param completion Completion callback, see `MTHAllocationsReportSymolicateCompletion`
 */
typedef void (^MTHAllocationsReportSymbolicateHandler)(NSString *mallocReportInJson, NSString *vmReportInJson, NSString *dyldImagesInfoInJson, MTHAllocationsReportSymbolicsCompletion completion);

/**
 Setup this handler to implement your own symbolics service completely.
 */
extern MTHAllocationsReportSymbolicateHandler mthAllocationSymbolicsHandler;


@interface MTHAllocationsViewController : UIViewController

@end

NS_ASSUME_NONNULL_END

//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 07/27/16
// Created by: Ji
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@interface MTHNetworkCurlLogger : NSObject

/**
 * Generates a cURL command equivalent to the given request.
 *
 * @param request The request to be translated
 */
+ (NSString *)curlCommandString:(NSURLRequest *)request;

@end

NS_ASSUME_NONNULL_END

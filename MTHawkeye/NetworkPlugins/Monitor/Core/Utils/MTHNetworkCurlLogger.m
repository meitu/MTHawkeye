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


#import "MTHNetworkCurlLogger.h"

@implementation MTHNetworkCurlLogger

+ (NSString *)curlCommandString:(NSURLRequest *)request {
    __block NSMutableString *curlCommandString = [NSMutableString stringWithFormat:@"curl -v -X %@ ", request.HTTPMethod];

    [curlCommandString appendFormat:@"\'%@\' ", request.URL.absoluteString];

    [request.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *val, BOOL *stop) {
        [curlCommandString appendFormat:@"-H \'%@: %@\' ", key, val];
    }];

    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:request.URL];
    if (cookies) {
        [curlCommandString appendFormat:@"-H \'Cookie:"];
        for (NSHTTPCookie *cookie in cookies) {
            [curlCommandString appendFormat:@" %@=%@;", cookie.name, cookie.value];
        }
        [curlCommandString appendFormat:@"\' "];
    }

    if (request.HTTPBody) {
        if ([request.allHTTPHeaderFields[@"Content-Length"] intValue] < 1024) {
            [curlCommandString appendFormat:@"-d \'%@\'",
                               [[NSString alloc] initWithData:request.HTTPBody
                                                     encoding:NSUTF8StringEncoding]];
        } else {
            [curlCommandString appendFormat:@"[TOO MUCH DATA TO INCLUDE]"];
        }
    }

    return curlCommandString;
}

@end

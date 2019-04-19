//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/21
// Created by: EuanC
//


#import "MTHawkeyeUserDefaults+NetworkMonitor.h"

@implementation MTHawkeyeUserDefaults (NetworkMonitor)

- (void)setNetworkMonitorOn:(BOOL)networkMonitorOn {
    [self setObject:@(networkMonitorOn) forKey:NSStringFromSelector(@selector(networkMonitorOn))];
}

- (BOOL)networkMonitorOn {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(networkMonitorOn))];
    return value ? value.boolValue : YES;
}

- (void)setNetworkTransactionBodyCacheOn:(BOOL)networkTransactionBodyCacheOn {
    [self setObject:@(networkTransactionBodyCacheOn) forKey:NSStringFromSelector(@selector(networkTransactionBodyCacheOn))];
}

- (BOOL)networkTransactionBodyCacheOn {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(networkTransactionBodyCacheOn))];
    return value ? value.boolValue : YES;
}

- (void)setResponseBodyCacheOn:(BOOL)responseBodyCacheOn {
    [self setObject:@(responseBodyCacheOn) forKey:NSStringFromSelector(@selector(responseBodyCacheOn))];
}

- (BOOL)responseBodyCacheOn {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(responseBodyCacheOn))];
    return value ? value.boolValue : YES;
}

- (void)setNetworkCacheLimitInMB:(float)networkCacheLimitInMB {
    [self setObject:@(networkCacheLimitInMB) forKey:NSStringFromSelector(@selector(networkCacheLimitInMB))];
}

- (float)networkCacheLimitInMB {
    NSNumber *value = [self objectForKey:NSStringFromSelector(@selector(networkCacheLimitInMB))];
    return value ? value.floatValue : 50.f;
}

@end

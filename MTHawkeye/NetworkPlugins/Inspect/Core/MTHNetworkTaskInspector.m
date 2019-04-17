//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 24/08/2017
// Created by: EuanC
//


#import "MTHNetworkTaskInspector.h"
#import "MTHNetworkRecorder.h"
#import "MTHNetworkTaskAdvice.h"
#import "MTHNetworkTaskInspectResults.h"
#import "MTHNetworkTaskInspection.h"
#import "MTHNetworkTaskInspectionAPIUsage.h"
#import "MTHNetworkTaskInspectionBandwidth.h"
#import "MTHNetworkTaskInspectionLatency.h"
#import "MTHNetworkTaskInspectionScheduling.h"
#import "MTHNetworkTaskInspectorContext.h"
#import "MTHNetworkTransaction.h"

@interface MTHNetworkTaskInspector ()

@property (nonatomic, copy) NSArray<MTHNetworkTaskInspection *> *inspections;

@property (nonatomic, strong, readwrite) MTHNetworkTaskInspectorContext *context;

@property (nonatomic, strong, readwrite) MTHNetworkTaskInspectResults *inspectResults;

@property (nonatomic, strong) dispatch_queue_t queue;

@property (nonatomic, assign) BOOL enabled;

@end


@implementation MTHNetworkTaskInspector

+ (instancetype)shared {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

+ (void)setEnabled:(BOOL)enabled {
    if ([MTHNetworkTaskInspector shared].enabled == enabled) {
        return;
    }

    if (enabled) {
        [MTHNetworkTaskInspector shared].queue = dispatch_queue_create("com.meitu.hawkeye.network.inspect", DISPATCH_QUEUE_SERIAL);
        [MTHNetworkTaskInspector shared].enabled = YES;
    } else {
        [MTHNetworkTaskInspector shared].queue = nil;
        [MTHNetworkTaskInspector shared].enabled = NO;
    }
}

+ (BOOL)isEnabled {
    return [MTHNetworkTaskInspector shared].enabled;
}

- (void)addInspection:(MTHNetworkTaskInspection *)inspection {
    if (!inspection) {
        return;
    }
    dispatch_async(self.queue, ^{
        NSMutableArray *tempInspections = self.inspections ? [self.inspections mutableCopy] : [NSMutableArray array];
        [tempInspections addObject:inspection];

        [self.inspectResults updateGroupsInfoWithInspections:@[ inspection ]];

        self.inspections = [tempInspections copy];
    });
}

// MARK: - inspect task
- (void)inspectTransactions:(NSArray<MTHNetworkTransaction *> *)transactions
          completionHandler:(void (^)(NSDictionary<NSString *, NSArray<MTHNetworkTaskAdvice *> *> *))completionHandler {
    NSDictionary *cache = nil;
    if (self.storageDelegate && [self.storageDelegate respondsToSelector:@selector(existNetworkInspectResultsCache)]) {
        cache = [self.storageDelegate existNetworkInspectResultsCache];
    }

    [self.context updateContextWithTransactions:transactions];

    NSMutableDictionary *advicesDict = @{}.mutableCopy;

    dispatch_async(self.queue, ^{
        for (NSInteger i = transactions.count - 1; i >= 0; i--) {
            MTHNetworkTransaction *_Nonnull transaction = transactions[i];
            NSString *key = [NSString stringWithFormat:@"%@", @(transaction.requestIndex)];
            if ([self existCacheForKey:key fromDict:cache]) {
                NSArray<MTHNetworkTaskAdvice *> *advices = [self cachedAdvicesForKey:key fromDict:cache];
                advicesDict[key] = advices;
            } else {
                NSArray<MTHNetworkTaskAdvice *> *advices = [self inspectTransaction:transaction];
                advicesDict[key] = advices;
            }
        }

        if (completionHandler)
            completionHandler([advicesDict copy]);
    });
}

- (BOOL)existCacheForKey:(NSString *)key fromDict:(NSDictionary *)cacheDict {
    NSDictionary *value = [cacheDict objectForKey:key];
    return value != nil;
}

- (NSArray<MTHNetworkTaskAdvice *> *)cachedAdvicesForKey:(NSString *)key fromDict:(NSDictionary *)cacheDict {
    NSDictionary *transactionDic = [cacheDict objectForKey:key];
    if (![[transactionDic objectForKey:@"result"] boolValue]) {

        NSDictionary *advicesDic = [transactionDic objectForKey:@"advices"];
        NSMutableArray<MTHNetworkTaskAdvice *> *advices = @[].mutableCopy;
        [advicesDic enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, id _Nonnull obj, BOOL *_Nonnull stop) {
            [obj enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key1, id _Nonnull obj1, BOOL *_Nonnull stop) {
                [self.inspectResults updateInspectedAdvices:obj1 groupName:key typeName:key1];
                [advices addObjectsFromArray:obj1];
            }];
        }];
        return [advices copy];
    }
    return nil;
}

- (NSArray<MTHNetworkTaskAdvice *> *)inspectTransaction:(MTHNetworkTransaction *)transaction {
    if ([self isHostInBlacklist:transaction.request.URL]) {
        return nil;
    }

    NSString *key = [NSString stringWithFormat:@"%@", @(transaction.requestIndex)];

    // IMPROVE: 是否简化存储逻辑，直接 advices 存储？
    NSMutableDictionary *inspectResult = @{}.mutableCopy;
    NSMutableArray *advices = [NSMutableArray array];
    for (MTHNetworkTaskInspection *inspection in self.inspections) {
        if (inspection.enabled) {
            NSArray<MTHNetworkTaskAdvice *> *curAdvices = inspection.inspectHandler(transaction, self.context);
            if (curAdvices.count > 0) {
                [advices addObjectsFromArray:curAdvices];
                [self.inspectResults updateResultsAsInspection:inspection inspectedAdvices:curAdvices];

                NSMutableDictionary *inspectResultGroup = [inspectResult objectForKey:inspection.group];
                if (!inspectResultGroup) {
                    [inspectResult setObject:@{}.mutableCopy forKey:inspection.group];
                    inspectResultGroup = [inspectResult objectForKey:inspection.group];
                }
                [inspectResultGroup addEntriesFromDictionary:@{inspection.name : curAdvices}];
            }
        }
    }

    NSMutableDictionary *inspectResultDic = @{}.mutableCopy;
    inspectResultDic[@"advices"] = [inspectResult copy];

    if (self.storageDelegate && [self.storageDelegate respondsToSelector:@selector(requestCacheNetworkInspectResult:withKey:)]) {
        [self.storageDelegate requestCacheNetworkInspectResult:inspectResultDic withKey:key];
    }

    return [advices copy];
}

- (BOOL)isHostInBlacklist:(NSURL *)requestURL {
    __block BOOL inHostBlacklist = NO;
    [self.hostBlackList enumerateObjectsUsingBlock:^(NSString *_Nonnull host, NSUInteger idx, BOOL *_Nonnull stop) {
        if ([requestURL.host hasSuffix:host]) {
            inHostBlacklist = YES;
            *stop = YES;
        }
    }];
    return inHostBlacklist;
}

// MARK: - getter
- (MTHNetworkTaskInspectorContext *)context {
    if (_context == nil) {
        _context = [[MTHNetworkTaskInspectorContext alloc] init];
    }
    return _context;
}

// 一直等到第一个网络返回后才初始化
- (NSArray<MTHNetworkTaskInspection *> *)inspections {
    if (_inspections == nil) {
        _inspections = @[
            [MTHNetworkTaskInspectionAPIUsage nilNSURLInspection],
            [MTHNetworkTaskInspectionAPIUsage unexpectedURLRequestInspection],
            [MTHNetworkTaskInspectionAPIUsage deprecatedURLConnectionInspection],
            [MTHNetworkTaskInspectionAPIUsage preferHTTP2Inspection],
            [MTHNetworkTaskInspectionAPIUsage timeoutConfigInspection],
            [MTHNetworkTaskInspectionAPIUsage urlSessionTaskManageInspection],
            [MTHNetworkTaskInspectionBandwidth responseContentEncodingInspection],
            [MTHNetworkTaskInspectionBandwidth duplicateRequestInspection],
            [MTHNetworkTaskInspectionBandwidth responseImagePayloadInspection],
            [MTHNetworkTaskInspectionLatency dnsCostInspection],
            [MTHNetworkTaskInspectionLatency httpKeepAliveInspection],
            [MTHNetworkTaskInspectionLatency tooManyHostInspection],
            [MTHNetworkTaskInspectionLatency redirectRequestInspection],
            [MTHNetworkTaskInspectionScheduling startupHeavyRequestTaskInspection],
            [MTHNetworkTaskInspectionScheduling startupDNSCostInspection],
            [MTHNetworkTaskInspectionScheduling startupTCPConnectionCostInspection],
            [MTHNetworkTaskInspectionScheduling TCPConnectionCostInspection],
            [MTHNetworkTaskInspectionScheduling requestTaskPriorityInspection],
            [MTHNetworkTaskInspectionScheduling shouldCancelledRequestTaskInspection],
        ];
        [self.inspectResults updateGroupsInfoWithInspections:_inspections];
    }
    return _inspections;
}

- (MTHNetworkTaskInspectResults *)inspectResults {
    if (_inspectResults == nil) {
        _inspectResults = [[MTHNetworkTaskInspectResults alloc] init];
    }
    return _inspectResults;
}

- (void)releaseNetworkTaskInspectorElement {
    _inspections = nil;
    _inspectResults = nil;
    _context = nil;
}

@end

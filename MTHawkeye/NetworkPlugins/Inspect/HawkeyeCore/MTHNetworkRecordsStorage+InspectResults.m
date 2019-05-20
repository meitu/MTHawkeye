//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/24
// Created by: EuanC
//


#import "MTHNetworkRecordsStorage+InspectResults.h"
#import "MTHNetworkTaskAdvice.h"
#import "MTHNetworkTaskInspector.h"

#import <MTAppenderFile/MTAppenderFile.h>
#import <MTHawkeye/MTHawkeyeLogMacros.h>
#import <MTHawkeye/MTHawkeyeStorage.h>
#import <objc/runtime.h>


static NSString *const kNetworkInspectResultsFileName = @"network-inspectResults";


@interface MTHawkeyeStorage (NetworkPrivate)

- (NSString *)loadMmapContentAtDirectory:(NSString *)directory fileName:(NSString *)fileName;

@end


/****************************************************************************/
#pragma mark -


@interface MTHNetworkRecordsStorage ()

@property (nonatomic, strong) MTAppenderFile *networkInspectResultsFile;

@end


@implementation MTHNetworkRecordsStorage (InspectResults)

- (void)requestCacheNetworkInspectResult:(NSDictionary *)inspectResultDic withKey:(nonnull NSString *)key {
    NSString *uniqueStr = key;
    NSMutableDictionary *dict = @{}.mutableCopy;

    NSDictionary *inspectResults = [inspectResultDic objectForKey:@"advices"];
    if (inspectResults.count > 0) {
        NSMutableDictionary *transactionDic = @{}.mutableCopy;
        transactionDic[@"result"] = @(false);

        [inspectResults enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key2, NSDictionary *_Nonnull obj2, BOOL *_Nonnull stop) {
            NSMutableDictionary *advicesDic = @{}.mutableCopy;
            [obj2 enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key1, id _Nonnull obj1, BOOL *_Nonnull stop) {
                NSMutableArray *advicesArray = @[].mutableCopy;
                [obj1 enumerateObjectsUsingBlock:^(MTHNetworkTaskAdvice *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                    NSMutableDictionary *userInfoDic = @{}.mutableCopy;

                    [obj.userInfo enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSArray<NSNumber *> *_Nonnull obj1, BOOL *_Nonnull stop) {
                        userInfoDic[key] = obj1;
                    }];

                    NSDictionary *dict = @{
                        @"typeId" : obj.typeId ?: @"",
                        @"level" : @(obj.level),
                        @"requestIndex" : @(obj.requestIndex),
                        @"adviceTitleText" : obj.adviceTitleText ?: @"",
                        @"adviceDescText" : obj.adviceDescText ?: @"",
                        @"suggestDescText" : obj.suggestDescText ?: @"",
                        @"userInfo" : userInfoDic ?: @"" // userInfoDic
                    };
                    [advicesArray addObject:dict];
                }];
                advicesDic[key1] = advicesArray;
            }];
            transactionDic[key2] = advicesDic;
        }];

        dict[uniqueStr] = transactionDic;

    } else {
        NSMutableDictionary *transactionDic = @{}.mutableCopy;
        transactionDic[@"result"] = @(true);
        dict[uniqueStr] = transactionDic;
    }
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict.copy
                                                       options:0
                                                         error:&error];
    if (!jsonData) {
        MTHLogWarn(@"persist network InspectResult failed: %@", error.localizedDescription);
    }
    NSString *value = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    dispatch_async([MTHawkeyeStorage shared].storeQueue, ^(void) {
        [self.networkInspectResultsFile appendText:value];
    });
}

- (NSDictionary *)existNetworkInspectResultsCache {
    __block NSString *fileContent;
    MTHawkeyeStorage *storage = [MTHawkeyeStorage shared];
    dispatch_sync(storage.storeQueue, ^(void) {
        fileContent = [storage loadMmapContentAtDirectory:storage.storeDirectory fileName:kNetworkInspectResultsFileName];
    });

    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    [fileContent enumerateLinesUsingBlock:^(NSString *_Nonnull line, BOOL *_Nonnull stop) {
        NSDictionary *transactionDict = [NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        if (!transactionDict || !transactionDict.count) {
            return;
        }
        NSMutableDictionary *decodeJsonDic = @{}.mutableCopy;
        [transactionDict enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, NSDictionary *_Nonnull obj, BOOL *_Nonnull stop) {
            if ([[obj objectForKey:@"result"] boolValue]) {
                decodeJsonDic[key] = obj;
            } else {
                NSMutableDictionary *adviceGroup = @{}.mutableCopy;
                [obj enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key2, NSDictionary *_Nonnull obj2, BOOL *_Nonnull stop) {
                    if ([key2 isEqualToString:@"result"]) {
                        return;
                    }
                    NSMutableDictionary *adviceType = @{}.mutableCopy;
                    [obj2 enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key1, NSArray *_Nonnull obj1, BOOL *_Nonnull stop) {
                        NSMutableArray *advices = @[].mutableCopy;
                        [obj1 enumerateObjectsUsingBlock:^(id _Nonnull obj3, NSUInteger idx, BOOL *_Nonnull stop) {
                            MTHNetworkTaskAdvice *tmp = [MTHNetworkTaskAdvice new];
                            tmp.typeId = [obj3 objectForKey:@"typeId"] ?: @"";
                            tmp.level = [[obj3 objectForKey:@"level"] integerValue];
                            tmp.requestIndex = [[obj3 objectForKey:@"requestIndex"] integerValue];
                            tmp.adviceTitleText = [obj3 objectForKey:@"adviceTitleText"];
                            tmp.adviceDescText = [obj3 objectForKey:@"adviceDescText"];
                            tmp.suggestDescText = [obj3 objectForKey:@"suggestDescText"];
                            tmp.userInfo = [obj3 objectForKey:@"userInfo"] ?: nil;

                            [advices addObject:tmp];
                        }];

                        adviceType[key1] = advices;
                    }];
                    adviceGroup[key2] = adviceType;
                }];

                NSDictionary *decodeDic = @{
                    @"result" : @(false),
                    @"advices" : adviceGroup
                };
                decodeJsonDic[key] = decodeDic;
            }

            [result addEntriesFromDictionary:decodeJsonDic];
        }];
    }];

    return result.copy;
}

- (MTAppenderFile *)networkInspectResultsFile {
    MTAppenderFile *resuleFile = objc_getAssociatedObject(self, _cmd);
    if (resuleFile == nil) {
        MTAppenderFile *file = [[MTAppenderFile alloc] initWithFileDir:[MTHawkeyeStorage shared].storeDirectory name:kNetworkInspectResultsFileName];
        [file open];
        [file appendText:@"networkInspectResultsFile"];
        objc_setAssociatedObject(self, _cmd, file, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        resuleFile = file;
    }
    return resuleFile;
}

@end

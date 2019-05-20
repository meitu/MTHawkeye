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


#import "MTHNetworkRecordsStorage.h"
#import "MTHNetworkTransaction.h"
#import "MTHawkeyeUtility.h"

#import <MTAppenderFile/MTAppenderFile.h>
#import <MTHawkeye/MTHawkeyeLogMacros.h>
#import <MTHawkeye/MTHawkeyeStorage.h>


@interface MTHawkeyeStorage (NetworkPrivate)

- (NSString *)loadMmapContentAtDirectory:(NSString *)directory fileName:(NSString *)fileName;

@end


@interface MTHNetworkRecordsStorage ()

@property (nonatomic, strong) MTAppenderFile *networkRecordsFile;

@end

@implementation MTHNetworkRecordsStorage

+ (instancetype)shared {
    static MTHNetworkRecordsStorage *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });

    return _sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
    }
    return self;
}

- (MTAppenderFile *)networkRecordsFile {
    if (_networkRecordsFile == nil) {
        MTAppenderFile *file = [[MTAppenderFile alloc] initWithFileDir:[MTHawkeyeStorage shared].storeDirectory name:@"network-transactions"];
        [file open];
        [file appendText:@"key,value"];
        _networkRecordsFile = file;
    }
    return _networkRecordsFile;
}

- (void)storeNetworkTransaction:(MTHNetworkTransaction *)transaction {
    NSDictionary *dict = [transaction dictionaryFromAllProperty];
    if ([dict count] == 0) {
        return;
    }

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict.copy options:0 error:&error];
    if (!jsonData) {
        MTHLogWarn(@"persist network transactions failed: %@", error.localizedDescription);
    }
    NSString *value = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    if (jsonData.length < 16 * 1024) {
        dispatch_async([MTHawkeyeStorage shared].storeQueue, ^(void) {
            [self.networkRecordsFile appendText:value];
        });
    } else {
        [self appendNetworkRecordsWithText:value];
    }
}

- (NSArray<MTHNetworkTransaction *> *)readNetworkTransactions {
    __block NSString *fileContent;
    MTHawkeyeStorage *storage = [MTHawkeyeStorage shared];
    dispatch_sync(storage.storeQueue, ^(void) {
        fileContent = [storage loadMmapContentAtDirectory:storage.storeDirectory fileName:@"network-transactions"];
    });
    NSMutableArray<MTHNetworkTransaction *> *transactions = [NSMutableArray array];
    NSMutableIndexSet *transactionIndexSet = [NSMutableIndexSet indexSet];
    [fileContent enumerateLinesUsingBlock:^(NSString *_Nonnull line, BOOL *_Nonnull stop) {
        NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
        if (!data)
            return;

        NSDictionary *transactionDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (!transactionDict || !transactionDict.count) {
            return;
        }
        MTHNetworkTransaction *transaction = [MTHNetworkTransaction transactionFromPropertyDictionary:transactionDict];
        if (transaction && ![transactionIndexSet containsIndex:transaction.requestIndex]) {
            [transactions addObject:transaction];
            [transactionIndexSet addIndex:transaction.requestIndex];
        }
    }];

    // 这里是对大于 16kb 的请求数据的处理
    NSArray *hugeTransactions = [self hugeNetworkRecords];
    for (NSString *transcationString in hugeTransactions) {
        NSData *data = [transcationString dataUsingEncoding:NSUTF8StringEncoding];
        if (!data)
            continue;

        NSDictionary *transactionDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (transactionDict && transactionDict.count > 0) {
            MTHNetworkTransaction *transaction = [MTHNetworkTransaction transactionFromPropertyDictionary:transactionDict];
            if (transaction && ![transactionIndexSet containsIndex:transaction.requestIndex]) {
                [transactions addObject:transaction];
                [transactionIndexSet addIndex:transaction.requestIndex];
            }
        }
    }

    if (!transactions.count) {
        return nil;
    }

    NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(requestIndex)) ascending:NO];
    transactions = [[transactions sortedArrayUsingDescriptors:@[ descriptor ]] copy];

    return transactions;
}

- (NSArray *)hugeNetworkRecords {
    __block NSArray *records = nil;
    dispatch_sync([MTHawkeyeStorage shared].storeQueue, ^{
        NSString *path = [NSString stringWithFormat:@"%@/%@", [MTHawkeyeStorage shared].storeDirectory, @"hugeNetworkRecords"];
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:path];
        NSString *recordStr = [[NSString alloc] initWithData:[fileHandle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        records = [recordStr componentsSeparatedByString:@"hawkeyeNetwork"];
    });
    return records;
}

// write networkFile
- (void)appendNetworkRecordsWithText:(NSString *)text {
    dispatch_async([MTHawkeyeStorage shared].storeQueue, ^{
        @autoreleasepool {
            NSString *path = [NSString stringWithFormat:@"%@/%@", [MTHawkeyeStorage shared].storeDirectory, @"hugeNetworkRecords"];
            NSString *appendStr = [text stringByAppendingString:@"hawkeyeNetwork"];
            if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
                [appendStr writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:nil];
                return;
            }
            NSData *data = [appendStr dataUsingEncoding:NSUTF8StringEncoding];
            if (data) {
                NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:path];
                [fileHandle seekToEndOfFile];
                [fileHandle writeData:data];
                [fileHandle closeFile];
            }
        }
    });
}

// MARK: -
+ (NSUInteger)getCurrentSessionRecordsFileSize {
    NSArray<NSString *> *currentSessionFiles = [self getCurrentSessionRecordsFilePathList];
    return [self getFileSizeOfPathList:currentSessionFiles];
}

+ (NSUInteger)getHistorySessionRecordsFileSize {
    NSArray<NSString *> *currentHistoryFiles = [self getHistorySessionRecordsFilePathList];
    return [self getFileSizeOfPathList:currentHistoryFiles];
}

+ (NSUInteger)getFileSizeOfPathList:(NSArray<NSString *> *)pathList {
    NSUInteger totalSize = 0;
    for (NSString *path in pathList) {
        NSNumber *fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize];
        totalSize += fileSize.integerValue;
    }
    return totalSize;
}

// MARK:
+ (void)trimCurrentSessionLargeRecordsToCost:(NSUInteger)costLimitInMB {
    NSUInteger costLimitInByte = costLimitInMB * 1024 * 1024;
    NSUInteger totalSize = [self getCurrentSessionRecordsFileSize];
    if (totalSize > costLimitInByte) {
        NSString *currentHugeRecordPath = [[MTHawkeyeStorage shared].storeDirectory stringByAppendingPathComponent:@"hugeNetworkRecords"];
        NSUInteger sizeCleaned = [self deleteNetworkRecordsWithFile:currentHugeRecordPath maxCleanSize:totalSize - costLimitInByte];
        totalSize -= sizeCleaned;
    }
}

+ (void)removeAllCurrentSessionRecords {
    NSArray<NSString *> *currentSessionRecordPath = [self getCurrentSessionRecordsFilePathList];
    [currentSessionRecordPath enumerateObjectsUsingBlock:^(NSString *_Nonnull path, NSUInteger idx, BOOL *_Nonnull stop) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }];
}

+ (void)removeAllHistorySessionRecords {
    NSArray<NSString *> *historySessionRecordPath = [self getHistorySessionRecordsFilePathList];
    [historySessionRecordPath enumerateObjectsUsingBlock:^(NSString *_Nonnull path, NSUInteger idx, BOOL *_Nonnull stop) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }];
}

+ (NSUInteger)deleteNetworkRecordsWithFile:(NSString *)filePath maxCleanSize:(NSUInteger)cleanSize {
    if (cleanSize == 0) {
        return 0;
    }

    NSUInteger fileSize = ((NSNumber *)[[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil] objectForKey:NSFileSize]).unsignedIntegerValue;
    if (cleanSize >= fileSize) {
        if ([[NSFileManager defaultManager] isDeletableFileAtPath:filePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        }
        return fileSize;
    }

    NSUInteger remainSize = fileSize - cleanSize;
    NSUInteger recordsSize = fileSize;
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
    NSString *recordStr = [[NSString alloc] initWithData:[fileHandle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
    NSArray *records = [recordStr componentsSeparatedByString:@"hawkeyeNetwork"];
    NSString *remainStr = @"";
    for (NSString *record in records) {
        if (recordsSize > remainSize) {
            recordsSize -= [record lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            continue;
        }
        if (record.length) {
            remainStr = [[remainStr stringByAppendingString:record] stringByAppendingString:@"hawkeyeNetwork"];
        }
    }
    [fileHandle truncateFileAtOffset:0];
    NSData *remainData = [remainStr dataUsingEncoding:NSUTF8StringEncoding];
    if (remainData)
        [fileHandle writeData:remainData];
    [fileHandle closeFile];

    return cleanSize;
}



// Records file
+ (NSArray<NSString *> *)getCurrentSessionRecordsFilePathList {
    NSArray<NSString *> *allRecordsFilePath = [self getAllRecordsFilePathList];
    NSMutableArray<NSString *> *currentSessionRecordPaths = @[].mutableCopy;
    for (NSString *path in allRecordsFilePath) {
        if ([path hasPrefix:[MTHawkeyeStorage shared].storeDirectory]) {
            [currentSessionRecordPaths addObject:path];
        }
    }
    return currentSessionRecordPaths.count > 0 ? [currentSessionRecordPaths copy] : nil;
}

+ (NSArray<NSString *> *)getHistorySessionRecordsFilePathList {
    NSArray<NSString *> *allRecordsFilePath = [self getAllRecordsFilePathList];
    NSMutableArray<NSString *> *historySessionRecordPaths = @[].mutableCopy;
    for (NSString *path in allRecordsFilePath) {
        if (![path hasPrefix:[MTHawkeyeStorage shared].storeDirectory]) {
            [historySessionRecordPaths addObject:path];
        }
    }
    return historySessionRecordPaths.count > 0 ? [historySessionRecordPaths copy] : nil;
}

+ (NSArray<NSString *> *)getAllRecordsFilePathList {
    NSString *rootStore = [MTHawkeyeUtility hawkeyeStoreDirectory];
    NSArray<NSString *> *recordsDir = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:rootStore error:nil];
    NSMutableArray<NSString *> *allFilePath = [NSMutableArray array];
    for (NSString *cacheDirName in recordsDir) {
        NSString *cacheDirPath = [rootStore stringByAppendingPathComponent:cacheDirName];
        NSArray<NSString *> *recordsFileName = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:cacheDirPath error:nil];
        [recordsFileName enumerateObjectsUsingBlock:^(NSString *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            if ([obj isEqualToString:@"network-transactions.mtlog"] ||
                [obj isEqualToString:@"network-inspectResults.mtlog"] ||
                [obj isEqualToString:@"hugeNetworkRecords"]) {
                [allFilePath addObject:[cacheDirPath stringByAppendingPathComponent:obj]];
            }
        }];
    }
    return [allFilePath copy];
}

@end

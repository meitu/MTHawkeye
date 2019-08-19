//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/9
// Created by: EuanC
//


#import "MTHawkeyeStorage.h"
#import "MTHawkeyeLogMacros.h"
#import "MTHawkeyeUtility.h"

#import <MTAppenderFile/MTAppenderFile.h>



@implementation MTHawkeyeStorageObject

+ (MTHawkeyeStorageObject *)createObjectWithCollection:(NSString *)collection key:(NSString *)key string:(NSString *)string {
    MTHawkeyeStorageObject *object = [[MTHawkeyeStorageObject alloc] init];
    object.collection = collection;
    object.key = key;
    object.string = string;
    return object;
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"%@,%@,%@", self.collection, self.key, self.string];
}

@end



/****************************************************************************/
#pragma mark -


NSTimeInterval kMTHawkeyeLogExpiredTime = 7 * 24 * 60 * 60;
NSString *const kMTHawkeyeCollectionKeyValueRecordsFileName = @"records";
NSUInteger kMTHawkeyeLogStoreMaxLength = 16 * 1024;

@interface MTHawkeyeStorage ()

@property (nonatomic, strong) dispatch_queue_t storeQueue;
@property (nonatomic, copy) NSString *storeDirectory;
@property (nonatomic, strong) MTAppenderFile *collectionKeyValueFile;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *recordByteLength;

@end


@implementation MTHawkeyeStorage

+ (instancetype)shared {
    static MTHawkeyeStorage *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });

    return _sharedInstance;
}

- (void)dealloc {
    [_collectionKeyValueFile close];
}

- (instancetype)init {
    if ((self = [super init])) {
        _storeDirectory = [MTHawkeyeUtility currentStorePath];
        [self rebuildHawkeyeStorageDirectoryIfNeed];

        _pageSize = 100;
        _recordByteLength = [NSMutableArray array];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            @autoreleasepool {
                [self autoTrimExpiredLog];
            }
        });
    }
    return self;
}

- (void)asyncStoreValue:(NSString *)value withKey:(NSString *)key inCollection:(NSString *)collection {
    dispatch_async(self.storeQueue, ^(void) {
        [self syncStoreValue:value withKey:key inCollection:collection];
    });
}

- (void)syncStoreValue:(NSString *)value withKey:(NSString *)key inCollection:(NSString *)collection {
    // don't use [NSString stringWithFormat] here, while in background,
    // it may cause to call autoreleasepoolNoPage. and sometimes it would crash.
    // (anonymous namespace)::AutoreleasePoolPage::autoreleaseNoPage(objc_object*) + 144

    NSInteger lineLength = value.length + 1 + key.length + 1 + collection.length + 1;
    char *line = (char *)malloc(lineLength);
    memset(line, 0, lineLength);

    NSInteger offset = 0;
    strncpy(line + offset, [collection UTF8String], collection.length);
    offset += collection.length;

    line[offset] = ',';
    offset++;

    strncpy(line + offset, [key UTF8String], key.length);
    offset += key.length;

    line[offset] = ',';
    offset++;

    strncpy(line + offset, [value UTF8String], value.length);
    offset += value.length;

    line[offset] = '\0';

#ifdef DEBUG
    NSAssert(lineLength < kMTHawkeyeLogStoreMaxLength, @"line length should less than 16KB");
#endif

    [self.collectionKeyValueFile appendUTF8Text:line];
    
    // 记录每一行字符的长度,'\n'占一个字节
    [self.recordByteLength addObject:@(lineLength)];
    
    if (line != NULL) {
        free(line);
    }
}

- (NSUInteger)readKeyValuesInCollection:(NSString *)collection
                                   keys:(NSArray<NSString *> *__autoreleasing *)outKeys
                                 values:(NSArray<NSString *> *__autoreleasing *)outStrings {
    __block NSString *fileContent;
    dispatch_sync(self.storeQueue, ^(void) {
        fileContent = [self loadMmapContentAtDirectory:self.storeDirectory fileName:kMTHawkeyeCollectionKeyValueRecordsFileName];
    });
    if (fileContent.length == 0)
        return 0;

    NSMutableArray<NSString *> *keys = [NSMutableArray array];
    NSMutableArray<NSString *> *strings = [NSMutableArray array];
    NSString *fixCollection = [collection stringByAppendingString:@","];
    [fileContent enumerateLinesUsingBlock:^(NSString *_Nonnull line, BOOL *_Nonnull stop) {
        if (![line hasPrefix:fixCollection])
            return;

        NSArray<NSString *> *parts = [self separateRealtimeRecord:line]; // eg. mem,1500349.4834,128
        if (parts.count == 3 && parts[1].length && parts[2].length) {
            [keys addObject:parts[1]];
            [strings addObject:parts[2]];
        }
    }];

    if (keys.count) {
        if (outKeys)
            *outKeys = [keys copy];
        if (outStrings)
            *outStrings = [strings copy];
    }

    return keys.count;
}

- (void)readKeyValuesInPageRange:(NSRange)pageRange
                    inCollection:(NSString *)inCollection
                         orderBy:(MTHawkeyeStorageOrderType)orderBy
                      usingBlock:(nonnull MTHawkeyeStoragePageFilterBlock)usingBlock {
    __block NSString *pageString = nil;
    NSUInteger perPageRecordsCount = self.pageSize;
    dispatch_sync(self.storeQueue, ^(void) {
        pageString = [self loadStringContentAtDirectory:self.storeDirectory
                                               fileName:kMTHawkeyeCollectionKeyValueRecordsFileName
                                              pageRange:pageRange];
    });

    // 在这段分页范围内请求不到数据
    if (!pageString) {
        for (int i = 0; i < pageRange.length; i++) {
            if (usingBlock) {
                usingBlock(pageRange.location + i, @[]);
            }
        }
        return;
    }

    NSMutableArray<MTHawkeyeStorageObject *> *objects = [NSMutableArray array];
    [pageString enumerateLinesUsingBlock:^(NSString *_Nonnull line, BOOL *_Nonnull stop) {
        NSArray<NSString *> *parts = [self separateRealtimeRecord:line]; // eg. mem,1500349.4834,128
        if (parts.count == 3 && parts[0] && parts[1].length && parts[2].length) {
            [objects addObject:[MTHawkeyeStorageObject createObjectWithCollection:parts[0] key:parts[1] string:parts[2]]];
        }
    }];

    NSArray<MTHawkeyeStorageObject *> *sortObject = objects;
    if (orderBy == kMTHawkeyeStorageOrderTypeDescending) {
        sortObject = [[objects reverseObjectEnumerator] allObjects];
    }

    // 在这段范围内有数据的分页
    NSUInteger sortedPageCount = ceil((float)sortObject.count / (float)perPageRecordsCount);
    for (int i = 0; i < sortedPageCount; i++) {
        NSUInteger loc = i * perPageRecordsCount;
        NSUInteger length = loc + perPageRecordsCount < sortObject.count ? perPageRecordsCount : sortObject.count - loc;
        NSArray<MTHawkeyeStorageObject *> *objects = [sortObject subarrayWithRange:NSMakeRange(loc, length)];
        if (inCollection) {
            NSMutableArray<MTHawkeyeStorageObject *> *collections = [NSMutableArray array];
            [objects enumerateObjectsUsingBlock:^(MTHawkeyeStorageObject *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                if ([obj.collection isEqualToString:inCollection]) {
                    [collections addObject:obj];
                }
            }];
            objects = collections;
        }

        if (usingBlock) {
            usingBlock(pageRange.location + i, objects);
        }
    }

    // 请求超过有数据的分页
    if (pageRange.length > sortedPageCount) {
        for (int i = 0; i < pageRange.length - sortedPageCount; i++) {
            if (usingBlock) {
                usingBlock(sortedPageCount + i, @[]);
            }
        }
    }
}

// MARK: -
- (NSRange)availablePages {
    NSUInteger avaliablePages = ceil((float)self.recordByteLength.count / (float)self.pageSize);
    return NSMakeRange(0, avaliablePages);
}

- (NSString *)loadStringContentAtDirectory:(NSString *)directory fileName:(NSString *)fileName pageRange:(NSRange)pageRange {
    NSUInteger eachPageCollectionCount = self.pageSize;
    NSArray<NSNumber *> *recordByteLength = [self.recordByteLength copy];
    NSUInteger startRecrodOffset = eachPageCollectionCount * pageRange.location;
    NSUInteger endRecordOffset = startRecrodOffset + pageRange.length * eachPageCollectionCount;
    if (recordByteLength.count <= startRecrodOffset || pageRange.length == 0) {
        return nil;
    }

    // 计算需要获取的字符串起始偏移量和长度
    NSUInteger startLengthOffset = 0, recordTotalLength = 0;
    for (NSUInteger i = 0; (i < recordByteLength.count) && (i < endRecordOffset); i++) {
        if (i < startRecrodOffset) {
            startLengthOffset += recordByteLength[i].integerValue;
        } else {
            recordTotalLength += recordByteLength[i].integerValue;
        }
    }

    NSFileManager *filemanager = [NSFileManager defaultManager];
    NSString *filePath = [directory stringByAppendingPathComponent:fileName];
    NSString *mmapPath = [filePath stringByAppendingPathExtension:@"mmap2"];
    NSString *flushedFilePath = [filePath stringByAppendingPathExtension:@"mtlog"];
    NSNumber *flushedFileSize = [[filemanager attributesOfItemAtPath:flushedFilePath error:nil] objectForKey:NSFileSize];

    NSFileHandle *flushedFileHandle = [NSFileHandle fileHandleForReadingAtPath:flushedFilePath];
    NSFileHandle *mmapFileHandle = [NSFileHandle fileHandleForReadingAtPath:mmapPath];

    // 如果起始偏移包含已经flushed的部分
    if (startLengthOffset < flushedFileSize.unsignedIntegerValue) {
        [flushedFileHandle seekToFileOffset:startLengthOffset];
        if (startLengthOffset + recordTotalLength > flushedFileSize.unsignedIntegerValue) {
            NSData *flushedStrData = [flushedFileHandle readDataOfLength:flushedFileSize.unsignedIntegerValue - startLengthOffset];
            NSData *mmapStrData = [mmapFileHandle readDataOfLength:recordTotalLength - (flushedFileSize.unsignedIntegerValue - startLengthOffset)];
            return [NSString stringWithFormat:@"%@%@", [NSString stringWithUTF8String:flushedStrData.bytes], [NSString stringWithUTF8String:mmapStrData.bytes]];
        }

        NSData *flushedStrData = [flushedFileHandle readDataOfLength:recordTotalLength];
        [flushedFileHandle closeFile];
        [mmapFileHandle closeFile];
        return [NSString stringWithUTF8String:flushedStrData.bytes];
    }

    // 如果起始偏移全在mmap部分
    [mmapFileHandle seekToFileOffset:startLengthOffset - flushedFileSize.unsignedIntegerValue];
    NSData *mmapStrData = [mmapFileHandle readDataOfLength:recordTotalLength];
    [flushedFileHandle closeFile];
    [mmapFileHandle closeFile];
    return [NSString stringWithUTF8String:mmapStrData.bytes];
}

// MARK: -
/**
 将一条 realtime 记录按规则切分成几部分。
 如：“cpu,1524211686.037469,1” 切割为：[“cpu”, "1524211686.037469", "1"]

 @param stringRecord 一条原始的字符串记录
 @return 切割出各个部分字符串的数组
 */
- (NSArray<NSString *> *)separateRealtimeRecord:(NSString *)stringRecord {
    NSRange firstCommaRange = [stringRecord rangeOfString:@","];
    NSUInteger firstCommaLocation = firstCommaRange.location;
    if (firstCommaLocation == NSNotFound) {
        return nil;
    }

    NSUInteger secondSubStringBegin = NSMaxRange(firstCommaRange);
    NSRange rangeAfterFirstComma = NSMakeRange(secondSubStringBegin, stringRecord.length - secondSubStringBegin);
    NSRange secondCommaRange = [stringRecord rangeOfString:@"," options:0 range:rangeAfterFirstComma];
    NSUInteger secondCommaLocation = secondCommaRange.location;
    if (secondCommaLocation == NSNotFound) {
        return nil;
    }

    NSRange secondSubStringRange = NSMakeRange(secondSubStringBegin, secondCommaLocation - secondSubStringBegin);
    NSString *firstString = [stringRecord substringToIndex:firstCommaLocation];
    NSString *secondString = [stringRecord substringWithRange:secondSubStringRange];
    NSString *finalString = [stringRecord substringFromIndex:NSMaxRange(secondCommaRange)];
    NSArray<NSString *> *subStrings = @[ firstString, secondString, finalString ];
    return subStrings;
}

// MARK: - Utils

// 读取文件内容操作
- (NSString *)loadMmapContentAtDirectory:(NSString *)directory fileName:(NSString *)fileName {
    NSString *filePath = [directory stringByAppendingPathComponent:fileName];
    NSString *mmapPath = [filePath stringByAppendingPathExtension:@"mmap2"];
    filePath = [filePath stringByAppendingPathExtension:@"mtlog"];

    NSMutableString *logs = [NSMutableString string];
    NSString *fileString = [NSString stringWithContentsOfFile:filePath usedEncoding:NULL error:nil];
    if (fileString) {
        [logs appendString:fileString];
    }

    NSString *mmapString = [NSString stringWithContentsOfFile:mmapPath usedEncoding:NULL error:nil];
    // mmap 被转储到日志文件后，mmap 第一个字可能会被直接标为 | \0 |
    if (mmapString.length && [mmapString characterAtIndex:0] != '\0') {
        // mmap2 contains dirty data after \r line. see ptrbuffer.cc PtrBuffer::Write
        NSRange range = [mmapString rangeOfString:@"\r"];
        if (range.location != NSNotFound) {
            mmapString = [mmapString substringToIndex:range.location];
        }
        [logs appendString:mmapString];
    }
    return logs;
}

- (void)autoTrimExpiredLog {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:[MTHawkeyeUtility currentStoreDirectoryNameFormat]];
    [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];

    NSString *hawkeyePath = [MTHawkeyeUtility hawkeyeStoreDirectory];
    NSArray<NSString *> *logDirectories = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:hawkeyePath error:NULL];
    logDirectories = [logDirectories sortedArrayUsingComparator:^NSComparisonResult(NSString *_Nonnull obj1, NSString *_Nonnull obj2) {
        return [obj2 compare:obj1];
    }];

    const NSUInteger kMaxKeepCount = 10;
    [logDirectories enumerateObjectsUsingBlock:^(NSString *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        NSDate *createDate = [dateFormatter dateFromString:obj];
        if (!createDate) // ignore other directory such as preferences.
            return;

        if (createDate && createDate.timeIntervalSinceNow < -kMTHawkeyeLogExpiredTime) {
            [[NSFileManager defaultManager] removeItemAtPath:[hawkeyePath stringByAppendingPathComponent:obj] error:NULL];
        } else if (idx >= kMaxKeepCount) {
            MTHLogInfo(@"Trim expired log: %@", obj);
            [[NSFileManager defaultManager] removeItemAtPath:[hawkeyePath stringByAppendingPathComponent:obj] error:NULL];
        }
    }];
}

// MARK: -

- (void)rebuildHawkeyeStorageDirectoryIfNeed {
    NSError *error;
    NSString *dir = self.storeDirectory;
    // create directory if not exist
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir]
        && ![[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&error]) {
        MTHLogWarn(@"[hawkeye][persistance] create directory %@ failed, %@ %@", dir, @(error.code), error.localizedDescription);
    }
}


// MARK: - getter

- (dispatch_queue_t)storeQueue {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_attr_t attr;
        attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT, 0);
        self->_storeQueue = dispatch_queue_create("com.meitu.hawkeye.storage", attr);
    });
    return _storeQueue;
}

- (MTAppenderFile *)collectionKeyValueFile {
    if (_collectionKeyValueFile == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            MTAppenderFile *file = [[MTAppenderFile alloc] initWithFileDir:self.storeDirectory name:kMTHawkeyeCollectionKeyValueRecordsFileName];
            [file open];

            // header
            [file appendText:@"collection,key,value"];

            // launch time
            NSString *launchTime = [NSString stringWithFormat:@"%@", @([MTHawkeyeUtility appLaunchedTime])];
            NSString *launchInfo = [NSString stringWithFormat:@"%@,%@,%@", @"launch-time", launchTime, launchTime];
            [file appendText:launchInfo];
            self->_collectionKeyValueFile = file;
        });
    }
    return _collectionKeyValueFile;
}

@end

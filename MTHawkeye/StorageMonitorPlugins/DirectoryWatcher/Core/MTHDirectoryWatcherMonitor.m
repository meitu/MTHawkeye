//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/11/7
// Created by: Huni
//


#import "MTHDirectoryWatcherMonitor.h"
#import "MTHDirectoryWatcher.h"

@interface MTHDirectoryWatchObject : NSObject
@property (nonatomic, strong) NSString *path;
@property (nonatomic, assign) NSInteger triggerLimitTimes;
@property (nonatomic, assign) NSUInteger fileSize;
@end

@implementation MTHDirectoryWatchObject

+ (MTHDirectoryWatchObject *)watchObjectWithPath:(NSString *)path triggerLimitTimes:(NSInteger)triggerLimitTimes {
    return [[MTHDirectoryWatchObject alloc] initWithPath:path triggerLimitTimes:triggerLimitTimes];
}

- (instancetype)initWithPath:(NSString *)path triggerLimitTimes:(NSInteger)triggerLimitTimes {
    if ((self = [super init])) {
        _path = path;
        _triggerLimitTimes = triggerLimitTimes;
        _fileSize = (NSUInteger)[MTHDirectoryWatcher fileSizeAtPath:_path];
    }
    return self;
}

- (BOOL)fileSizeChanged {
    NSUInteger size = (NSUInteger)[MTHDirectoryWatcher fileSizeAtPath:_path];
    BOOL changed = size != _fileSize ? YES : NO;
    _fileSize = size;
    return changed;
}

@end

#pragma mark -

@interface MTHDirectoryWatcherMonitor ()
@property (nonatomic, assign) BOOL isWatching;
@property (atomic, strong) NSMutableArray<MTHDirectoryWatchObject *> *watchingObjects;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) dispatch_source_t detectTimer;
@end

@implementation MTHDirectoryWatcherMonitor

- (id)init {
    (self = [super init]);
    if (self) {
        _watchingObjects = [NSMutableArray array];
        _lock = [[NSLock alloc] init];
        _detectInterval = 40;
    }
    return self;
}

- (void)dealloc {
    [self stopWatching];
    _detectTimer = nil;
    _watcherTriggerLimitFiredCallback = nil;
    _watcherChangeCallback = nil;
}

+ (instancetype)shared {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (NSArray<NSString *> *)watchPaths {
    NSMutableArray *paths = [NSMutableArray array];
    [self.lock lock];
    for (MTHDirectoryWatchObject *object in self.watchingObjects) {
        [paths addObject:object.path];
    }
    [self.lock unlock];
    return paths;
}

- (dispatch_source_t)detectTimer {
    if (!_detectTimer) {
        __weak typeof(self) weakSelf = self;
        _detectTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
        dispatch_source_set_timer(_detectTimer, DISPATCH_TIME_NOW, _detectInterval * NSEC_PER_SEC, 0);
        dispatch_source_set_event_handler(_detectTimer, ^{
            @autoreleasepool {
                [weakSelf detectWatchingPath];
            }
        });
    }
    return _detectTimer;
}

- (void)setDetectInterval:(NSTimeInterval)detectInterval {
    if (fabs(_detectInterval - detectInterval) < DBL_EPSILON) {
        _detectInterval = detectInterval;

        if (_detectTimer) {
            dispatch_source_cancel(_detectTimer);
            _detectTimer = nil;
        }
    }
}

#pragma mark - Path Manager
- (void)startWatching {
    if (self.isWatching) {
        return;
    }

    if (!_detectTimer) {
        dispatch_resume(self.detectTimer);
    }
    self.isWatching = YES;
}

- (void)stopWatching {
    [self.lock lock];
    [self.watchingObjects removeAllObjects];
    [self.lock unlock];

    if (_detectTimer) {
        dispatch_source_cancel(_detectTimer);
        _detectTimer = nil;
    }

    self.isWatching = NO;
}

- (void)addMonitorPath:(NSString *)path triggerLimit:(NSUInteger)triggerLimit {
    if (!path || !path.length) {
        return;
    }

    NSArray *watchingPath = [self watchPaths];
    [self.lock lock];
    if (![watchingPath containsObject:path]) {
        [self.watchingObjects addObject:[MTHDirectoryWatchObject watchObjectWithPath:path triggerLimitTimes:triggerLimit]];
    }
    [self.lock unlock];
}

- (void)removePath:(NSString *)path {
    if (!path || !path.length) {
        return;
    }

    [self.lock lock];
    __block MTHDirectoryWatchObject *removeObj = nil;
    [self.watchingObjects enumerateObjectsUsingBlock:^(MTHDirectoryWatchObject *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        if ([path isEqualToString:obj.path]) {
            removeObj = obj;
            *stop = YES;
        }
    }];
    !removeObj ?: [self.watchingObjects removeObject:removeObj];
    [self.lock unlock];
}

#pragma mark - Detect
- (void)detectWatchingPath {
    if (!self.watchingObjects.count) {
        [self stopWatching];
        return;
    }

    NSMutableArray *triggerLimitObjects = [NSMutableArray array];
    NSMutableArray *changedObjects = [NSMutableArray array];

    [self.lock lock];
    for (MTHDirectoryWatchObject *watchObjct in self.watchingObjects) {
        watchObjct.triggerLimitTimes -= 1;
        if (watchObjct.triggerLimitTimes < 0) {
            [triggerLimitObjects addObject:watchObjct];
            continue;
        }

        ![watchObjct fileSizeChanged] ?: [changedObjects addObject:watchObjct];
    }
    for (MTHDirectoryWatchObject *firedObject in triggerLimitObjects) {
        [self.watchingObjects removeObject:firedObject];
    }
    [self.lock unlock];

    for (MTHDirectoryWatchObject *firedObject in triggerLimitObjects) {
        if (self.watcherTriggerLimitFiredCallback) {
            self.watcherTriggerLimitFiredCallback(firedObject.path);
        }
    }

    for (MTHDirectoryWatchObject *changedObject in changedObjects) {
        if (self.watcherChangeCallback) {
            self.watcherChangeCallback(changedObject.path, changedObject.fileSize);
        }
    }
}

@end

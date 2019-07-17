//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/4
// Created by: EuanC
//


#import "MTHawkeyeClient.h"
#import "MTHawkeyeAppStat.h"
#import "MTHawkeyeLogMacros.h"
#import "MTHawkeyeStorage.h"
#import "MTHawkeyeUtility.h"


@interface MTHawkeyeClient ()

@property (nonatomic, copy) MTHawkeyeClientPluginsSetupHandler pluginsSetupHandler;
@property (nonatomic, copy) MTHawkeyeClientPluginsCleanHandler pluginsCleanHandler;

@property (atomic, strong) NSArray<id<MTHawkeyePlugin>> *plugins;
@property (atomic, strong) NSArray<id<MTHawkeyePlugin>> *statusFlushPlugins;

@property (nonatomic, strong) dispatch_source_t statusFlushTimer;
@property (nonatomic, strong) dispatch_queue_t statusFlushQueue;

@property (nonatomic, assign) BOOL running;

@end


@implementation MTHawkeyeClient

- (void)dealloc {
    [self unobserveAppActivity];
    [self unobserveUserDefaultsChange];
}

+ (instancetype)shared {
    static MTHawkeyeClient *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init {
    if ((self = [super init])) {
        [self observeUserDefaultsChange];
        [self observeAppActivity];
    }
    return self;
}

- (void)addPlugin:(id<MTHawkeyePlugin>)plugin {
    NSMutableArray *plugins = self.plugins ? self.plugins.mutableCopy : @[].mutableCopy;
    [plugins addObject:plugin];
    self.plugins = plugins.copy;

    if ([plugin respondsToSelector:@selector(receivedFlushStatusCommand)]) {
        NSMutableArray *statusFlushPlugins = self.statusFlushPlugins ? self.statusFlushPlugins.mutableCopy : @[].mutableCopy;
        [statusFlushPlugins addObject:plugin];
        self.statusFlushPlugins = statusFlushPlugins.copy;
    }
}

- (void)removePlugin:(id<MTHawkeyePlugin>)plugin {
    if (![self.plugins containsObject:plugin])
        return;

    NSMutableArray *plugins = self.plugins ? self.plugins.mutableCopy : @[].mutableCopy;
    [plugins removeObject:plugin];
    self.plugins = plugins.copy;

    if (![self.statusFlushPlugins containsObject:plugin])
        return;

    NSMutableArray *statusFlushPlugins = self.statusFlushPlugins ? self.statusFlushPlugins.mutableCopy : @[].mutableCopy;
    [statusFlushPlugins removeObject:plugin];
    self.statusFlushPlugins = statusFlushPlugins;
}

- (nullable id<MTHawkeyePlugin>)pluginFromID:(NSString *)pluginID {
    NSInteger idx = [self.plugins indexOfObjectPassingTest:^BOOL(id<MTHawkeyePlugin> _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        return [[[obj class] pluginID] isEqualToString:pluginID];
    }];
    if (idx == NSNotFound)
        return nil;
    else
        return self.plugins[idx];
}

// MARK: -

- (void)setPluginsSetupHandler:(MTHawkeyeClientPluginsSetupHandler)pluginsSetupHandler
           pluginsCleanHandler:(MTHawkeyeClientPluginsCleanHandler)pluginsCleanHandler {
    self.pluginsSetupHandler = pluginsSetupHandler;
    self.pluginsCleanHandler = pluginsCleanHandler;
}

- (void)startServer {
    if (![MTHawkeyeUserDefaults shared].hawkeyeOn)
        return;

    [self doStart];
}

- (void)stopServer {
    [self doStop];
}

- (void)doStart {
    if (self.running)
        return;

    self.running = YES;
    MTHLogInfo(@"----- hawkeye client start -----");

    if (self.pluginsSetupHandler) {
        NSMutableArray *plugins = self.plugins ? [self.plugins mutableCopy] : @[].mutableCopy;
        self.pluginsSetupHandler(plugins);

        NSMutableArray *statusFlushPlugins = @[].mutableCopy;
        for (id<MTHawkeyePlugin> plugin in plugins) {
            if ([plugin respondsToSelector:@selector(receivedFlushStatusCommand)]) {
                [statusFlushPlugins addObject:plugin];
            }
        }
        self.plugins = [plugins copy];
        self.statusFlushPlugins = [statusFlushPlugins copy];
    }

    // if a plugin need start earlier, it should load it earlier by itself.
    [self.plugins makeObjectsPerformSelector:@selector(hawkeyeClientDidStart)];

    [self startStatusFlushTimer];
}

- (void)doStop {
    if (!self.running)
        return;

    self.running = NO;

    [self stopStatusFlushTimer];

    [self.plugins makeObjectsPerformSelector:@selector(hawkeyeClientDidStop)];

    if (self.pluginsCleanHandler) {
        NSMutableArray *plugins = self.plugins ? [self.plugins mutableCopy] : @[].mutableCopy;
        self.pluginsCleanHandler(plugins);

        self.plugins = plugins;
        self.statusFlushPlugins = nil;
    }

    MTHLogInfo(@"----- hawkeye client stopped -----");
}

- (void)startStatusFlushTimer {
    dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
    self.statusFlushQueue = dispatch_queue_create("com.meitu.hawkeye.status_flush", attr);
    self.statusFlushTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.statusFlushQueue);

    // Need Improve: if you need to change statusFlushIntevalInSeconds, config it before start.
    uint64_t interval = [MTHawkeyeUserDefaults shared].statusFlushIntevalInSeconds * NSEC_PER_SEC;
    dispatch_source_set_timer(self.statusFlushTimer, DISPATCH_TIME_NOW, interval, 0);
    dispatch_source_set_event_handler(self.statusFlushTimer, ^{
        @autoreleasepool {
            [self statusFlushTimerFired];
        }
    });
    dispatch_resume(self.statusFlushTimer);
}

- (void)stopStatusFlushTimer {
    if (self.statusFlushTimer) {
        dispatch_source_cancel(self.statusFlushTimer);
        self.statusFlushTimer = nil;
        self.statusFlushQueue = nil;
    }
}

- (void)statusFlushTimerFired {
    [self doBuildInFlushStatusTasks];

    [self.statusFlushPlugins enumerateObjectsUsingBlock:^(id<MTHawkeyePlugin> _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        [obj receivedFlushStatusCommand];
    }];
}

- (void)doBuildInFlushStatusTasks {
    NSString *time = [NSString stringWithFormat:@"%@", @([MTHawkeyeUtility currentTime])];
    BOOL forceFlush = [MTHawkeyeUserDefaults shared].statusFlushKeepRedundantRecords;

    // record memory usage
    if ([MTHawkeyeUserDefaults shared].recordMemoryUsage) {
        static CGFloat preResident = 0.f;
        static CGFloat preMemFootprint = 0.f;
        CGFloat resident = MTHawkeyeAppStat.memoryAppUsed / 1024.f / 1024.f;
        CGFloat memFootprint = MTHawkeyeAppStat.memoryFootprint / 1024.f / 1024.f;
        if (forceFlush || (fabs(resident - preResident) > DBL_EPSILON) || (fabs(memFootprint - preMemFootprint) > DBL_EPSILON)) {
            preResident = resident;
            preMemFootprint = memFootprint;

            NSString *residentStr = [NSString stringWithFormat:@"%.2f", resident];
            NSString *memFootprintStr = [NSString stringWithFormat:@"%.2f", memFootprint];

            [[MTHawkeyeStorage shared] asyncStoreValue:residentStr withKey:time inCollection:@"mem"];
            [[MTHawkeyeStorage shared] asyncStoreValue:memFootprintStr withKey:time inCollection:@"r-mem"];
        }
    }

    // record cpu usage
    if ([MTHawkeyeUserDefaults shared].recordCPUUsage) {
        static double preCPUUsage = 0.f;
        double cpuUsage = MTHawkeyeAppStat.cpuUsedByAllThreads;
        if (forceFlush || (fabs(cpuUsage - preCPUUsage) > DBL_EPSILON)) {
            preCPUUsage = cpuUsage;

            NSString *cpuUsageStr = [NSString stringWithFormat:@"%.1f", cpuUsage * 100.f];
            [[MTHawkeyeStorage shared] asyncStoreValue:cpuUsageStr withKey:time inCollection:@"cpu"];
        }
    }
}

// MARK: - AppLife Observe
- (void)observeAppActivity {
    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidEnterBackgroundNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *_Nonnull note) {
                    [self stopStatusFlushTimer];
                }];

    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationWillEnterForegroundNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *_Nonnull note) {
                    if ([MTHawkeyeUserDefaults shared].hawkeyeOn) {
                        [self stopStatusFlushTimer];
                        [self startStatusFlushTimer];
                    }
                }];
}

- (void)unobserveAppActivity {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
}

// MARK: - UserDefaults Observe
- (void)observeUserDefaultsChange {
    __weak __typeof(self) weakSelf = self;
    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(hawkeyeOn))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                if ([newValue boolValue]) {
                    [weakSelf doStart];
                } else {
                    [weakSelf doStop];
                }
            }];
}

- (void)unobserveUserDefaultsChange {
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(hawkeyeOn))];
}

@end

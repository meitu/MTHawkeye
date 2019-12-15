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


#import "MTFPSHawkeyeAdaptor.h"
#import "MTHFPSTrace.h"
#import "MTHawkeyeClient.h"
#import "MTHawkeyeStorage.h"
#import "MTHawkeyeUserDefaults.h"
#import "MTHawkeyeUtility.h"

@interface MTFPSHawkeyeAdaptor () <MTHFPSTraceDelegate>
@property (nonatomic, assign) BOOL fpsMonitorOn;
@property (nonatomic, strong) MTHFPSGLRenderCounter *firstActiveRenderCounter;
@end

@implementation MTFPSHawkeyeAdaptor

- (void)dealloc {
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:@"fpsMonitorOn"];
}

- (instancetype)init {
    if ((self = [super init])) {
        _fpsMonitorOn = [self fpsMonitorSetOnDefault];

        __weak __typeof(self) weakSelf = self;
        [[MTHawkeyeUserDefaults shared]
            mth_addObserver:self
                     forKey:@"fpsMonitorOn"
                withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                    if ([newValue boolValue])
                        [weakSelf hawkeyeClientDidStart];
                    else
                        [weakSelf hawkeyeClientDidStop];
                }];
    }
    return self;
}

- (void)setFpsMonitorOn:(BOOL)fpsMonitorOn {
    if (_fpsMonitorOn == fpsMonitorOn)
        return;

    [[MTHawkeyeUserDefaults shared] setObject:@(fpsMonitorOn) forKey:@"fpsMonitorOn"];
}

- (BOOL)fpsMonitorSetOnDefault {
    NSNumber *on = [[MTHawkeyeUserDefaults shared] objectForKey:@"fpsMonitorOn"];
    return on ? on.boolValue : NO;
}

// MARK: - MTHawkeyePlugin
+ (NSString *)pluginID {
    return @"fps-tracer";
}

- (void)hawkeyeClientDidStart {
    if (self.fpsMonitorOn)
        return;

    if (![MTHFPSTrace shared].isRunning) {
        [[MTHFPSTrace shared] start];
        [[MTHFPSTrace shared] addDelegate:self];
    }
}

- (void)hawkeyeClientDidStop {
    if ([MTHFPSTrace shared].isRunning) {
        [[MTHFPSTrace shared] stop];
        [[MTHFPSTrace shared] removeDelegate:self];
    }
}

- (void)receivedFlushStatusCommand {
    if (![MTHFPSTrace shared].isRunning)
        return;

    NSString *time = [NSString stringWithFormat:@"%@", @([MTHawkeyeUtility currentTime])];
    BOOL forceFlush = [MTHawkeyeUserDefaults shared].statusFlushKeepRedundantRecords;

    // store fps.
    {
        static NSInteger preFPS = 0;
        NSInteger curFPSValue = [MTHFPSTrace shared].fpsValue;
        BOOL fpsChanged = (preFPS != curFPSValue);
        if (fpsChanged || forceFlush) {
            NSString *fpsValue = [NSString stringWithFormat:@"%@", @(curFPSValue)];
            [[MTHawkeyeStorage shared] asyncStoreValue:fpsValue withKey:time inCollection:@"fps"];
        }
        preFPS = curFPSValue;
    }

    // store GPUImage present fps.
    if ([MTHFPSTrace shared].gpuImageViewFPSEnable) {
        static NSInteger preGPUImageFPS = 0;
        NSInteger curGPUImageFPSValue = self.firstActiveRenderCounter.fpsValue;
        BOOL gpuImageDisplaying = self.firstActiveRenderCounter.isActive;
        BOOL gpuImageFPSChanged = (preGPUImageFPS != curGPUImageFPSValue);
        if (gpuImageFPSChanged || forceFlush) {
            // 平时记录时只记录了变化时的数据，这里补充记录退出前的最后一次数据
            if (preGPUImageFPS > 0 && curGPUImageFPSValue == 0) {
                [[MTHawkeyeStorage shared] asyncStoreValue:[NSString stringWithFormat:@"%@", @(preGPUImageFPS)] withKey:time inCollection:@"gl-fps"];
            }

            if (gpuImageDisplaying && curGPUImageFPSValue > 0.f) {
                NSString *glfps = [NSString stringWithFormat:@"%@", @(curGPUImageFPSValue)];
                [[MTHawkeyeStorage shared] asyncStoreValue:glfps withKey:time inCollection:@"gl-fps"];
            }
        }
        preGPUImageFPS = curGPUImageFPSValue;
    }
}

// MARK: - MTHFPSTraceDelegate
- (void)fpsValueDidChanged:(NSInteger)FPSValue {
}

- (void)glRenderCounterValueChange:(MTHFPSGLRenderCounter *)rendererCounter {
    if (self.firstActiveRenderCounter == nil) {
        self.firstActiveRenderCounter = rendererCounter;
    }

    if ([self.firstActiveRenderCounter.identifier isEqualToString:rendererCounter.identifier] && !rendererCounter.isActive) {
        self.firstActiveRenderCounter = nil;
    }
}
@end

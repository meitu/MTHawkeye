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


#import "MTHNetworkInspectHawkeyeAdaptor.h"
#import "MTHNetworkRecordsStorage+InspectResults.h"
#import "MTHNetworkTaskInspector.h"
#import "MTHawkeyeUserDefaults+NetworkInspect.h"


@implementation MTHNetworkInspectHawkeyeAdaptor

- (void)dealloc {
    [self unobserveNetworkInspectSettings];
}

- (instancetype)init {
    if (self = [super init]) {
        [self observeNetworkInspectSettings];
    }
    return self;
}

// MARK: - MTHawkeyePlugin
+ (NSString *)pluginID {
    return @"network-inspect";
}

- (void)hawkeyeClientDidStart {
    if (![MTHawkeyeUserDefaults shared].networkInspectOn) {
        return;
    }

    [MTHNetworkTaskInspector setEnabled:YES];
    [MTHNetworkTaskInspector shared].storageDelegate = [MTHNetworkRecordsStorage shared];
}

- (void)hawkeyeClientDidStop {
    [MTHNetworkTaskInspector setEnabled:NO];
    [MTHNetworkTaskInspector shared].storageDelegate = nil;

    [[MTHNetworkTaskInspector shared] releaseNetworkTaskInspectorElement];
}

// MARK: - User defaults
- (void)observeNetworkInspectSettings {
    __weak __typeof(self) weakSelf = self;
    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(networkInspectOn))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                if ([newValue boolValue])
                    [weakSelf hawkeyeClientDidStart];
                else
                    [weakSelf hawkeyeClientDidStop];
            }];

    // do cache limit change
}

- (void)unobserveNetworkInspectSettings {
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(networkInspectOn))];
}

@end

//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 30/09/2017
// Created by: EuanC
//


#import "MTHANRRecord.h"

@implementation MTHANRMainThreadStallingSnapshot

- (void)dealloc {
    if (self->stackframes) {
        free(self->stackframes);
        self->stackframes = nil;
    }
}

- (NSString *)description {
    NSMutableString *desc = [NSMutableString string];
    [desc appendFormat:@"%@: cpu: %.2f%%, frames:", @(self.time), self.cpuUsed * 100];

    for (int i = 0; i < self->stackframesSize; ++i) {
        uintptr_t frame = self->stackframes[i];
        [desc appendFormat:@"%p,", (void *)frame];
    }

    if (self->stackframesSize > 0) {
        return [desc substringToIndex:desc.length - 1];
    } else {
        return [desc copy];
    }
}

@end

@implementation MTHANRRecord

- (NSString *)description {
    NSMutableString *desc = [NSMutableString string];
    [desc appendFormat:@"--- ANR event: ---\n"];
    [desc appendFormat:@"time: %@\n", @(self.startFrom)];
    [desc appendFormat:@"duration: %@s\n", @(self.durationInSeconds)];
    [desc appendFormat:@"snapshots: \n"];
    for (MTHANRMainThreadStallingSnapshot *snapshot in self.stallingSnapshots) {
        [desc appendFormat:@"%@\n", snapshot];
    }
    [desc appendString:@"\n"];

    return [desc copy];
}

@end

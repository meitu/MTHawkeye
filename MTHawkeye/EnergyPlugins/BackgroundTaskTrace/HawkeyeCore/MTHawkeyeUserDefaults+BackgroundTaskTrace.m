//
//  MTHawkeyeUserDefaults+BackgroundTaskTrace.m
//  MTHawkeyeInjection
//
//  Created by Zed on 2019/5/23.
//

#import "MTHawkeyeUserDefaults+BackgroundTaskTrace.h"

@implementation MTHawkeyeUserDefaults (BackgroundTaskTrace)

- (void)setBackgroundTaskTraceOn:(BOOL)backgroundTaskTraceOn {
    [self setObject:@(backgroundTaskTraceOn) forKey:NSStringFromSelector(@selector(backgroundTaskTraceOn))];
}

- (BOOL)backgroundTaskTraceOn {
    NSNumber *on = [self objectForKey:NSStringFromSelector(@selector(backgroundTaskTraceOn))];
    return on ? on.boolValue : YES;
}

@end

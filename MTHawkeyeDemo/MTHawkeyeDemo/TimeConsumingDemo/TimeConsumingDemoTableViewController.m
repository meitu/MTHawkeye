//
//  TimeConsumingDemoTableViewController.m
//  MTHawkeyeDemo
//
//  Created by EuanC on 2019/3/7.
//  Copyright © 2019 Meitu. All rights reserved.
//

#import "TimeConsumingDemoTableViewController.h"
#import <MTHawkeye/MTHTimeIntervalRecorder.h>
#import <MTHawkeye/MTHawkeyeUtility.h>

@interface TimeConsumingDemoTableViewController ()

@end

@implementation TimeConsumingDemoTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self lightTestActions];
    [self lightTestActions2];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [[MTHTimeIntervalRecorder shared] recordCustomEvent:@"CustomEvent::In::ViewDidAppear"];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0:
                [self runHeavyTaskOnMainThread];
                break;
            case 1:
                [self logCustomTimeEvent];
            default:
                break;
        }
    }
}

- (void)runHeavyTaskOnMainThread {
    [self testAction];
}

- (void)logCustomTimeEvent {
    static int i = 0;
    if (i % 5 == 0) {
        NSTimeInterval now = [MTHawkeyeUtility currentTime];
        NSString *event = [NSString stringWithFormat:@"A custom event log with time %@, idx: %@.", @(now), @(i)];
        NSString *extra = @"Quaerat hic vitae officia dignissimos dolorem accusantium neque.";
        [[MTHTimeIntervalRecorder shared] recordCustomEvent:event extra:extra];
    } else if (i % 3 == 0) {
        NSString *event = [NSString stringWithFormat:@"Simple custom event log, idx: %@", @(i)];
        [[MTHTimeIntervalRecorder shared] recordCustomEvent:event];
    } else if (i % 2 == 0) {
        NSString *event = [NSString stringWithFormat:@"Event: %@", @(i)];
        [[MTHTimeIntervalRecorder shared] recordCustomEvent:event];
    }

    i++;
}

- (void)testAction {
    double time1 = CFAbsoluteTimeGetCurrent();
    [self testActions];

    double time2 = CFAbsoluteTimeGetCurrent();

    NSLog(@"actual blocking : %.2fms", (time2 - time1) * 1000.f);
}

- (void)lightTestActions {
    NSMutableString *str = [[NSMutableString alloc] init];
    for (int i = 0; i < 5000; i++) {
        for (int j = 0; j < 10; j++) {
            [str appendString:@"1"];
        }
    }
}

- (void)lightTestActions2 {
    for (int i = 0; i < 3; i++) {
        [self lightTestActions];
    }
}

- (void)testActions {
    NSMutableString *str = [[NSMutableString alloc] init];
    for (int i = 0; i < 5000; i++) {
        for (int j = 0; j < 1000; j++) {
            [str appendString:@"1"];
        }
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSMutableString *str1 = [[NSMutableString alloc] init];
        for (int i = 0; i < 5000; i++) {
            for (int j = 0; j < 1000; j++) {
                [str1 appendString:@"1"];
            }
        }
    });
    dispatch_async(dispatch_queue_create("test queue", DISPATCH_QUEUE_CONCURRENT), ^{
        NSMutableString *str2 = [[NSMutableString alloc] init];
        for (int i = 0; i < 5000; i++) {
            for (int j = 0; j < 1000; j++) {
                [str2 appendString:@"1"];
            }
        }
    });
}

@end

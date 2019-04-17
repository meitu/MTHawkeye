//
//  EnergyDemoTableViewController.m
//  MTHawkeyeDemo
//
//  Created by EuanC on 2019/3/7.
//  Copyright © 2019 Meitu. All rights reserved.
//

#import "EnergyDemoTableViewController.h"

@interface EnergyDemoTableViewController ()

@property (nonatomic, strong) NSThread *thread1;
@property (nonatomic, strong) NSThread *thread2;
@property (nonatomic, strong) NSThread *thread3;

@end

@implementation EnergyDemoTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    switch (indexPath.section) {
        case 0:
            switch (indexPath.row) {
                case 0:
                    [self startHeavyTask1];
                    break;
                case 1:
                    [self stopHeavyTask1];
                    break;
            }
            break;
        case 1:
            switch (indexPath.row) {
                case 0:
                    [self startHeavyTask2];
                    break;
                case 1:
                    [self stopHeavyTask2];
                    break;
            }
            break;
        case 2:
            switch (indexPath.row) {
                case 0:
                    [self startHeavyTask3];
                    break;
                case 1:
                    [self stopHeavyTask3];
                    break;
            }
            break;

        default:
            break;
    }
}

- (void)task1 {
    while ([[NSThread currentThread] isCancelled] == NO) {
        NSMutableString *str = [NSMutableString string];
        for (NSInteger i = 0; i < 30000; i++) {
            [str appendFormat:@"%@", @(i)];
            [self task1SubTask];
        }
        usleep(600);
    }
}

- (void)task1SubTask {
    NSMutableString *str = [NSMutableString string];
    for (NSInteger i = 0; i < 3; i++) {
        [str appendFormat:@"%@", @(i)];
    }
}

- (void)task2 {
    while ([[NSThread currentThread] isCancelled] == NO) {
        while ([[NSThread currentThread] isCancelled] == NO) {
            NSMutableString *str = [NSMutableString string];
            for (NSInteger i = 0; i < 60000; i++) {
                [str appendFormat:@"%@", @(i)];
            }
        }
        usleep(300);
    }
}

- (void)task3 {
    while ([[NSThread currentThread] isCancelled] == NO) {
        while ([[NSThread currentThread] isCancelled] == NO) {
            NSMutableString *str = [NSMutableString string];
            for (NSInteger i = 0; i < 90000; i++) {
                [str appendFormat:@"%@", @(i)];
            }
        }
        usleep(100);
    }
}

// MARK: -
- (void)startHeavyTask1 {
    if (!self.thread1) {
        self.thread1 = [[NSThread alloc] initWithTarget:self selector:@selector(task1) object:nil];
        self.thread1.name = @"demo.thread.1";
        [self.thread1 start];

        NSLog(@"thread 1 start running");

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self stopHeavyTask1];
        });
    }
}

- (void)stopHeavyTask1 {
    if (self.thread1) {
        [self.thread1 cancel];
        self.thread1 = nil;

        NSLog(@"thread 1 stop running");
    }
}

- (void)startHeavyTask2 {
    if (!self.thread2) {
        self.thread2 = [[NSThread alloc] initWithTarget:self selector:@selector(task2) object:nil];
        self.thread2.name = @"demo.thread.2";
        [self.thread2 start];

        NSLog(@"thread 2 start running");
    }
}

- (void)stopHeavyTask2 {
    if (self.thread2) {
        [self.thread2 cancel];
        self.thread2 = nil;

        NSLog(@"thread 2 stop running");
    }
}

- (void)startHeavyTask3 {
    if (!self.thread3) {
        self.thread3 = [[NSThread alloc] initWithTarget:self selector:@selector(task3) object:nil];
        self.thread3.name = @"demo.thread.3";
        [self.thread3 start];

        NSLog(@"thread 3 start running");
    }
}

- (void)stopHeavyTask3 {
    if (self.thread3) {
        [self.thread3 cancel];
        self.thread3 = nil;

        NSLog(@"thread 3 stop running");
    }
}

@end

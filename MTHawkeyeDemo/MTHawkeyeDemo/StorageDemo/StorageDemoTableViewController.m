//
//  StorageDemoTableViewController.m
//  MTHawkeyeDemo
//
//  Created by EuanC on 2019/3/7.
//  Copyright © 2019 Meitu. All rights reserved.
//

#import "StorageDemoTableViewController.h"
#import <MTHawkeye/MTHawkeyeUtility.h>

@interface StorageDemoTableViewController ()

@end

@implementation StorageDemoTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)addFilesCount:(NSInteger)count {
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"tmp/"];
    NSTimeInterval time = [MTHawkeyeUtility currentTime];

    for (NSInteger i = 0; i < count; i++) {
        NSMutableString *content = [NSMutableString string];
        for (NSInteger j = 0; j < 300; j++) {
            [content appendString:@"Et qui eligendi ullam voluptas nobis. Id eius veniam molestiae enim voluptatem et. Esse ipsum sed ut nesciunt praesentium aut dolor sint. Ducimus vitae error aspernatur minima sed.\n"];
        }
        [content appendFormat:@"%ld", (long)i];

        NSString *file = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%.0f-%ld", time, (long)i]];
        NSError *error;
        [content writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            NSLog(@"%@", error);
        }
    }
}

- (void)clearTmpFiles {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *directory = [NSHomeDirectory() stringByAppendingPathComponent:@"tmp/"];
    NSError *error = nil;
    for (NSString *file in [fm contentsOfDirectoryAtPath:directory error:&error]) {
        BOOL success = [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@", directory, file] error:&error];
        if (!success || error) {
            NSLog(@"%@", error);
        }
    }
}

#pragma mark - Table view data source

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                [self addFilesCount:1000];
            });
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                [self clearTmpFiles];
            });
        }
    }
}

@end

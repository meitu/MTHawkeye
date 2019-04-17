//
//  MemoryAllocationTestViewController.m
//  MTHawkeyeDemo
//
//  Created by EuanC on 29/07/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import "MemoryAllocationTestViewController.h"
#import <MTHawkeye/UIDevice+MTHLivingObjectSniffer.h>
#import <mach/mach.h>


@interface MemoryAllocationTestViewController ()

@property (weak, nonatomic) IBOutlet UILabel *residentLabel;
@property (weak, nonatomic) IBOutlet UILabel *virtualLabel;

@property (assign, nonatomic) CGFloat preResidentInMB;
@property (assign, nonatomic) CGFloat preVirtualInMB;

@end


@implementation MemoryAllocationTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self updateMemoryDisplay];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)updateMemoryDisplay {
    int64_t resident = [UIDevice currentDevice].memoryAppUsed;
    int64_t virtual = [self virtualMemoryAppUsed];
    CGFloat residentInMB = resident / 1024.f / 1024.f;
    CGFloat virtualInMB = virtual / 1024.f / 1024.f;
    if (self.preResidentInMB == 0)
        self.preResidentInMB = residentInMB;
    if (self.preVirtualInMB == 0)
        self.preVirtualInMB = virtualInMB;

    CGFloat residentDiff = residentInMB - self.preResidentInMB;
    CGFloat virtualDiff = virtualInMB - self.preVirtualInMB;

    self.residentLabel.text = [NSString stringWithFormat:@"%.2fMB + %.2f", residentInMB, residentDiff];
    self.virtualLabel.text = [NSString stringWithFormat:@"%.2fMB + %.2f", virtualInMB, virtualDiff];
    [self.residentLabel sizeToFit];
    [self.virtualLabel sizeToFit];

    self.preVirtualInMB = virtualInMB;
    self.preResidentInMB = residentInMB;
}

/*
 Clean Memory: 闪存中有备份，可再次获取。如 `system framework`, `binary executable of your app`, `memory mapped file`.
 Dirty Memory: 所有非 Clean Memory，系统无法回收。包括 `Heap allocation`, `caches`, `decompressed images`.
 
 Virtual Memory = Clean + Dirty
 Resident Memory = Dirty + Clean memory that loaded in physical memory.
 */

- (IBAction)add50Clean:(id)sender {
    __unused char *buf = malloc(50 * 1024 * 1024);

    [self updateMemoryDisplay];
}

- (IBAction)add50Dirty:(id)sender {
    char *buf = malloc(50 * 1024 * 1024 * sizeof(char));
    for (int i = 0; i < 50 * 1024 * 1024; ++i) {
        buf[i] = (char)rand();
    }
    [self updateMemoryDisplay];
}

- (IBAction)add10v50:(id)sender {
    int *buf = (int *)malloc(50 * 1024 * 1024 * sizeof(char));
    for (int i = 0; i < 10 * 1024 * 1024; ++i) {
        buf[i] = (int)rand();
    }
    [self updateMemoryDisplay];
}

- (int64_t)virtualMemoryAppUsed {
    struct task_basic_info info;
    mach_msg_type_number_t size = (sizeof(task_basic_info_data_t) / sizeof(natural_t));
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    if (kerr == KERN_SUCCESS) {
        return info.virtual_size;
    } else {
        return 0;
    }
}

@end

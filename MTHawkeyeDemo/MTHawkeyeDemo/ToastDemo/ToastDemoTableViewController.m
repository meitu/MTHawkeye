//
//  ToastDemoTableViewController.m
//  MTHawkeyeDemo
//
//  Created by EuanC on 2019/3/7.
//  Copyright © 2019 Meitu. All rights reserved.
//

#import "ToastDemoTableViewController.h"
#import <MTHawkeye/MTHToast.h>

@interface ToastDemoTableViewController ()

@end

@implementation ToastDemoTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0:
                [self showShortToast];
                break;
            case 1:
                [self showLongToast];
                break;
            case 2:
                [self showDetailToastWithButton];
                break;
            case 3:
                [self showDetailToastWithButton2];
                break;

            default:
                break;
        }
    }
}

- (void)showShortToast {
    [[MTHToast shared] showToastWithMessage:@"Test Message" handler:nil];
}

- (void)showLongToast {
    [[MTHToast shared] showToastWithMessage:@"MINE eye hath played the painter and hath stelled Thy beauty's form in table of my heart;My body is the frame wherein 'tis held,And perspective it is best painter's art.For through the painter must you see his skillTo fine where your true image pictured lies,Which in my bosom's shop is hanging still,That hath his windows glazèd with thine eyes.MINE eye hath played the painter and hath stelled Thy beauty's form in table of my heart;My body is the frame wherein 'tis held,And perspective it is best painter's art.For through the painter must you see his skillTo fine where your true image pictured lies,Which in my bosom's shop is hanging still,That hath his windows glazèd with thine eyes.MINE eye hath played the painter and hath stelled Thy beauty's form in table of my heart;My body is the frame wherein 'tis held,And perspective it is best painter's art.For through the painter must you see his skillTo fine where your true image pictured lies,Which in my bosom's shop is hanging still,That hath his windows glazèd with thine eyes." handler:nil];
}

- (void)showDetailToastWithButton {
    NSArray *array = @[ [MTHToastBtnHandler actionWithTitle:@"Feedback"
                                                      style:MTHToastActionStyleLeft
                                                    handler:^{
                                                        NSLog(@"Feedback triggered");
                                                    }] ];

    [[MTHToast shared] showToastWithStyle:MTHToastStyleDetail title:@"Title" content:@"This is content" detailContent:@"MINE eye hath played the painter and hath stelled Thy beauty's form in table of my heart;My body is the frame wherein 'tis held,And perspective it is best painter's art.For through the painter must you see his skillTo fine where your true image pictured lies,Which in my bosom's shop is hanging still,That hath his windows glazèd with thine eyes.MINE eye hath played the painter and hath stelled Thy beauty's form in table of my heart;My body is the frame wherein 'tis held,And perspective it is best painter's art.For through the painter must you see his skillTo fine where your true image pictured lies,Which in my bosom's shop is hanging still,That hath his windows glazèd with thine eyes.MINE eye hath played the painter and hath stelled Thy beauty's form in table of my heart;My body is the frame wherein 'tis held,And perspective it is best painter's art.For through the painter must you see his skillTo fine where your true image pictured lies,Which in my bosom's shop is hanging still,That hath his windows glazèd with thine eyes." duration:1.3 handler:nil buttonHandlers:array autoHiddenBeOccluded:NO];
}

- (void)showDetailToastWithButton2 {
    NSArray *array = @[ [MTHToastBtnHandler actionWithTitle:@"Feedback"
                                                      style:MTHToastActionStyleLeft
                                                    handler:^{
                                                        NSLog(@"Feedback triggered");
                                                    }],
        [MTHToastBtnHandler actionWithTitle:@"More"
                                      style:MTHToastActionStyleRight
                                    handler:^{
                                        NSLog(@"More button clicked");
                                    }] ];

    [[MTHToast shared] showToastWithStyle:MTHToastStyleDetail title:@"Title" content:@"This is content" detailContent:@"MINE eye hath played the painter and hath stelled Thy beauty's form in table of my heart;My body is the frame wherein 'tis held,And perspective it is best painter's art.For through the painter must you see his skillTo fine where your true image pictured lies,Which in my bosom's shop is hanging still,That hath his windows glazèd with thine eyes.MINE eye hath played the painter and hath stelled Thy beauty's form in table of my heart;My body is the frame wherein 'tis held,And perspective it is best painter's art.For through the painter must you see his skillTo fine where your true image pictured lies,Which in my bosom's shop is hanging still,That hath his windows glazèd with thine eyes.MINE eye hath played the painter and hath stelled Thy beauty's form in table of my heart;My body is the frame wherein 'tis held,And perspective it is best painter's art.For through the painter must you see his skillTo fine where your true image pictured lies,Which in my bosom's shop is hanging still,That hath his windows glazèd with thine eyes." duration:1.3 handler:nil buttonHandlers:array autoHiddenBeOccluded:NO];
}

@end

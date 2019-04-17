//
//  LeakingPropertiesSecondTestViewController.h
//  MTHawkeyeDemo
//
//  Created by EuanC on 03/08/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SharedInstanceExample;

@interface LeakingPropertiesSecondTestViewController : UIViewController

@property (nonatomic, strong) SharedInstanceExample *sampleViewModel;

@end

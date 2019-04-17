//
//  ReusePropertyTestViewController.h
//  MTHawkeyeDemo
//
//  Created by EuanC on 04/08/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ANormalViewModel;

/**
 vc 持有一个在 vc 创建之前就已经存在的属性，检测到第二次后，应该断定为共享对象
 */
@interface ReusePropertyTestViewController : UIViewController

@property (nonatomic, strong) ANormalViewModel *viewModel;
@property (nonatomic, strong) ANormalViewModel *sharedViewModel;
@property (nonatomic, strong) ANormalViewModel *existMainViewModel;

@end

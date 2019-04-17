//
//  LeakingPropertiesTestViewController.m
//  MTHawkeyeDemo
//
//  Created by EuanC on 03/08/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import "LeakingPropertiesTestViewController.h"
#import "ALeakingViewModel.h"
#import "EnormousViewModel.h"
#import "LeakingPropertiesSecondTestViewController.h"
#import "SharedInstanceExample.h"

#pragma mark -
@interface ALeakingView : UIView
@property (nonatomic, strong) id leakTarget;
@end

@implementation ALeakingView
@end

@interface ALeakingSubView : ALeakingView
@end

@implementation ALeakingSubView
@end

@interface ALeakingTableViewCell : UITableViewCell
@property (nonatomic, strong) id leakTarget;
@end

@implementation ALeakingTableViewCell
@end

#pragma mark -

@interface LeakingPropertiesTestViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) SharedInstanceExample *sampleViewModel;
@property (nonatomic, strong) ALeakingViewModel *anObjectWillLeak;
@property (nonatomic, strong) AViewModelWithLeakingProperty *anObjectWillLeakDeep;
@property (nonatomic, strong) SharedInstanceExample *anSharedInstance;
@property (strong, nonatomic) MBCCameraCapturingConfiguration *configuration;
@property (nonatomic, strong) NSMutableArray *subViewContainer;
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation LeakingPropertiesTestViewController

- (void)dealloc {
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.subViewContainer = [NSMutableArray array];
    for (NSInteger i = 0; i < 10; ++i) {
        ALeakingView *firstLevelView = [[ALeakingView alloc] initWithFrame:CGRectMake(20, 300, 60, 60)];
        firstLevelView.backgroundColor = [UIColor lightGrayColor];

        for (NSInteger j = 0; j < 1; ++j) {
            ALeakingSubView *secondLevelView = [[ALeakingSubView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
            secondLevelView.leakTarget = firstLevelView;
            secondLevelView.backgroundColor = [UIColor grayColor];
            [firstLevelView addSubview:secondLevelView];
        }

        [self.view addSubview:firstLevelView];
        [self.subViewContainer addObject:firstLevelView];
    }

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 370, self.view.frame.size.width, 300) style:UITableViewStyleGrouped];
    [self.tableView registerClass:[ALeakingTableViewCell class] forCellReuseIdentifier:@"ALeakingCell"];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    LeakingPropertiesSecondTestViewController *second = (LeakingPropertiesSecondTestViewController *)[segue destinationViewController];
    self.sampleViewModel = [[SharedInstanceExample alloc] init];
    second.sampleViewModel = self.sampleViewModel;
}

- (IBAction)retainA:(id)sender {
    NSLog(@"%@", self.anObjectWillLeak);
}

- (IBAction)retainB:(id)sender {
    NSLog(@"%@", self.anObjectWillLeakDeep);
}

- (IBAction)retainC:(id)sender {
    NSLog(@"%@", self.anSharedInstance);
}

- (ALeakingViewModel *)anObjectWillLeak {
    if (_anObjectWillLeak == nil) {
        _anObjectWillLeak = [[ALeakingViewModel alloc] init];
    }
    return _anObjectWillLeak;
}

- (MBCCameraCapturingConfiguration *)configuration {
    if (_configuration == nil) {
        _configuration = [[MBCCameraCapturingConfiguration alloc] init];
    }
    return _configuration;
}

- (AViewModelWithLeakingProperty *)anObjectWillLeakDeep {
    if (_anObjectWillLeakDeep == nil) {
        _anObjectWillLeakDeep = [[AViewModelWithLeakingProperty alloc] init];
    }
    return _anObjectWillLeakDeep;
}

- (SharedInstanceExample *)anSharedInstance {
    if (_anSharedInstance == nil) {
        _anSharedInstance = [[SharedInstanceExample alloc] init];
    }
    return _anSharedInstance;
}

#pragma mark -
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 20;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ALeakingTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ALeakingCell" forIndexPath:indexPath];
    cell.textLabel.text = [NSString stringWithFormat:@"Leaking Cell: %ld", indexPath.row + 1];

    // xcode memory graph can't catch this.
    cell.leakTarget = tableView; // cell;
    return cell;
}
@end

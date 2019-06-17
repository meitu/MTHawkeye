//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2017/9/8
// Created by: 潘名扬
//


#import "MTHNetworkMonitorFilterViewController.h"
#import "MTHNetworkTaskInspectResults.h"
#import "MTHNetworkTaskInspection.h"
#import "MTHNetworkTaskInspector.h"
#import "MTHNetworkTaskInspectorContext.h"
#import "MTHNetworkTransactionsURLFilter.h"

static NSString *const kMTHNetworkTransactionsFilterSettingKey = @"kMTHNetworkTransactionsFilterSettingKey";

static NSString *const kMTHNetworkTransactionFilterStatusCodeKey = @"kMTHNetworkTransactionFilterStatusCodeKey";
static NSString *const kMTHNetworkTransactionFilterDeselectedInspectionKey = @"kMTHNetworkTransactionFilterDeselectedInspectionKey";
static NSString *const kMTHNetworkTransactionFilterDeselectedHostKey = @"kMTHNetworkTransactionFilterDeselectedHostKey";


typedef NS_ENUM(NSUInteger, MTHNetworkMonitorFilterViewSectionType) {
    MTHNetworkMonitorFilterViewSectionTypeHostList = 0,
    MTHNetworkMonitorFilterViewSectionTypeStatusCode,
    MTHNetworkMonitorFilterViewSectionTypeInspectionList,
    MTHNetworkMonitorFilterViewSectionTypeCount,
};


// MARK: - MTHNetworkMonitorFilterViewRow
@interface MTHNetworkMonitorFilterViewRow : NSObject

@property (nonatomic, assign) BOOL isSelected;
@property (nonatomic, copy) NSString *title;

@end

@implementation MTHNetworkMonitorFilterViewRow

- (instancetype)init {
    (self = [super init]);
    if (self) {
        _isSelected = YES;
    }
    return self;
}

@end


// MARK: - MTHNetworkMonitorFilterViewSection
@interface MTHNetworkMonitorFilterViewSection : NSObject

@property (nonatomic, assign) MTHNetworkMonitorFilterViewSectionType type;
@property (nonatomic, copy) NSArray<MTHNetworkMonitorFilterViewRow *> *rows;
@property (nonatomic, copy) NSString *title;

@end

@implementation MTHNetworkMonitorFilterViewSection
@end


// MARK: - MTHNetworkMonitorFilterViewController
@interface MTHNetworkMonitorFilterViewController ()

@property (nonatomic, copy) NSArray<MTHNetworkMonitorFilterViewSection *> *sections;

@property (nonatomic, copy) NSArray<MTHNetworkTaskInspection *> *inspections; /**< inspection 过滤 **/
@property (nonatomic, copy) NSArray<NSString *> *hosts;                       /**< 一级域名过滤 **/

@property (nonatomic, assign) BOOL isDataSetup;
@property (nonatomic, assign) CGFloat contentHeight;

@property (nonatomic, strong, nullable) MTHNetworkMonitorFilterViewSection *hostFilterSection;
@property (nonatomic, strong, nullable) MTHNetworkMonitorFilterViewSection *statusFilterSection;
@property (nonatomic, strong, nullable) MTHNetworkMonitorFilterViewSection *inspectionFilterSection;

@end

@implementation MTHNetworkMonitorFilterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Filter";

    UIBarButtonItem *doneBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(selectionDone:)];
    // 以 Tag 来区分是哪个 Section 上的全选按钮，或是 Navigation Bar 上的全选按钮；
    self.navigationItem.rightBarButtonItem = doneBtn;

    [self.tableView registerClass:[UITableViewCell class]
           forCellReuseIdentifier:NSStringFromClass([UITableViewCell class])];

    [self setupDataIfNeed];
}

- (CGSize)preferredContentSize {
    [self setupDataIfNeed];

    CGFloat contentHeight = self.contentHeight > 0 ? self.contentHeight : 250;

    return CGSizeMake(ceil(CGRectGetWidth([UIScreen mainScreen].bounds) * 0.9), contentHeight);
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self feedbackSelectedOptions];
}

- (void)setupDataIfNeed {
    if (self.isDataSetup) {
        return;
    }

    self.isDataSetup = YES;

    NSMutableArray<MTHNetworkMonitorFilterViewSection *> *sections = [NSMutableArray arrayWithCapacity:3];

    // Domains Section
    NSSet<MTHTopLevelDomain *> *topLevelDomains = [MTHNetworkTaskInspector shared].context.topLevelDomains;
    if (topLevelDomains.count > 0) {
        NSMutableArray<NSString *> *topLevelDomainStrings = [NSMutableArray array];
        for (MTHTopLevelDomain *domain in topLevelDomains) {
            if (domain.domainString) {
                [topLevelDomainStrings addObject:domain.domainString];
            }
        }
        self.hosts = [topLevelDomainStrings copy];

        self.hostFilterSection = [[MTHNetworkMonitorFilterViewSection alloc] init];
        NSMutableArray<MTHNetworkMonitorFilterViewRow *> *domainsRows = [NSMutableArray arrayWithCapacity:3];

        for (NSString *domain in self.hosts) {
            MTHNetworkMonitorFilterViewRow *row = [[MTHNetworkMonitorFilterViewRow alloc] init];
            row.title = domain;
            [domainsRows addObject:row];
        }
        self.hostFilterSection.rows = [domainsRows copy];
        self.hostFilterSection.title = @"Domains";
        self.hostFilterSection.type = MTHNetworkMonitorFilterViewSectionTypeHostList;
        [sections addObject:self.hostFilterSection];
    }

    // Status Code Section
    self.statusFilterSection = [[MTHNetworkMonitorFilterViewSection alloc] init];
    NSMutableArray<MTHNetworkMonitorFilterViewRow *> *statusCodeRows = [NSMutableArray arrayWithCapacity:6];
    for (NSInteger i = 0; i < 6; i++) {
        MTHNetworkMonitorFilterViewRow *row = [[MTHNetworkMonitorFilterViewRow alloc] init];
        if (i < 5) {
            row.title = [NSString stringWithFormat:@"%@xx", @(i + 1)];
        } else {
            row.title = @"Failed";
        }
        [statusCodeRows addObject:row];
    }
    self.statusFilterSection.rows = [statusCodeRows copy];
    self.statusFilterSection.title = @"Status Codes";
    self.statusFilterSection.type = MTHNetworkMonitorFilterViewSectionTypeStatusCode;
    [sections addObject:self.statusFilterSection];

    // Inspections Section
    if ([MTHNetworkTaskInspector isEnabled]) {
        NSArray<MTHNetworkTaskInspectionsGroup *> *inspectionGroups = [MTHNetworkTaskInspector shared].inspectResults.groups;
        NSMutableArray<MTHNetworkTaskInspectionWithResult *> *inspections = [NSMutableArray array];
        for (MTHNetworkTaskInspectionsGroup *group in inspectionGroups) {
            if (group.inspections) {
                [inspections addObjectsFromArray:group.inspections];
            }
        }
        self.inspections = [inspections copy];

        self.inspectionFilterSection = [[MTHNetworkMonitorFilterViewSection alloc] init];
        NSMutableArray<MTHNetworkMonitorFilterViewRow *> *inspectionsRows = [NSMutableArray arrayWithCapacity:3];

        for (MTHNetworkTaskInspectionWithResult *inspection in self.inspections) {
            MTHNetworkMonitorFilterViewRow *row = [[MTHNetworkMonitorFilterViewRow alloc] init];
            row.title = inspection.inspection.displayName;
            [inspectionsRows addObject:row];
        }
        self.inspectionFilterSection.rows = [inspectionsRows copy];
        self.inspectionFilterSection.title = @"Inspections";
        self.inspectionFilterSection.type = MTHNetworkMonitorFilterViewSectionTypeInspectionList;
        [sections addObject:self.inspectionFilterSection];
    }

    __block CGFloat contentHeight = 0.f;
    [sections enumerateObjectsUsingBlock:^(MTHNetworkMonitorFilterViewSection *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        contentHeight += [self tableView:self.tableView heightForHeaderInSection:idx];
        contentHeight += ([self tableView:self.tableView heightForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:idx]] * obj.rows.count);
    }];
    self.contentHeight = contentHeight;

    self.sections = [sections copy];
    [self loadFilterSettingFromCache];
}

- (void)feedbackSelectedOptions {
    if (!self.filterDelegate || ![self.filterDelegate respondsToSelector:@selector(filterUpdatedWithStatusCodes:inspections:hosts:)]) {
        return;
    }

    NSMutableArray *selectedInspections = [NSMutableArray arrayWithCapacity:self.inspections.count];
    NSMutableArray *selectedHosts = [NSMutableArray arrayWithCapacity:self.hosts.count];
    MTHNetworkTransactionStatusCode selectedStatusCodes = MTHNetworkTransactionStatusCodeNone;

    for (NSInteger i = 0; i < self.inspections.count; i++) {
        if (self.inspectionFilterSection.rows[i].isSelected) {
            [selectedInspections addObject:self.inspections[i]];
        }
    }

    for (NSInteger i = 0; i < self.hosts.count; i++) {
        if (self.hostFilterSection.rows[i].isSelected) {
            [selectedHosts addObject:self.hosts[i]];
        }
    }

    for (NSInteger i = 0; i < 6; i++) {
        BOOL isSelected = self.statusFilterSection.rows[i].isSelected;
        if (i < 5) {
            selectedStatusCodes |= (isSelected ? 1 << i : MTHNetworkTransactionStatusCodeNone);
        } else {
            selectedStatusCodes |= (isSelected ? MTHNetworkTransactionStatusCodeFailed : MTHNetworkTransactionStatusCodeNone);
        }
    }

    [self.filterDelegate filterUpdatedWithStatusCodes:selectedStatusCodes inspections:selectedInspections hosts:selectedHosts];
    [self saveToCacheWithStatusCodes:selectedStatusCodes inspections:selectedInspections hosts:selectedHosts];
}

- (void)saveToCacheWithStatusCodes:(MTHNetworkTransactionStatusCode)statusCodes
                       inspections:(NSArray<MTHNetworkTaskInspection *> *)inspections
                             hosts:(NSArray<NSString *> *)hosts {
    // 只保存被取消选中的
    NSMutableArray<MTHNetworkTaskInspection *> *allInspections = [NSMutableArray arrayWithArray:self.inspections];
    [allInspections removeObjectsInArray:inspections];
    NSArray<MTHNetworkTaskInspection *> *deselectedInspections = allInspections;
    NSMutableArray *deselectedInspectionNameArray = [NSMutableArray arrayWithCapacity:deselectedInspections.count];
    for (MTHNetworkTaskInspection *inspection in deselectedInspections) {
        if (inspection.name) {
            [deselectedInspectionNameArray addObject:inspection.name];
        }
    }

    NSMutableArray<NSString *> *allHosts = [NSMutableArray arrayWithArray:self.hosts];
    [allHosts removeObjectsInArray:hosts];
    NSArray<NSString *> *deselectedHosts = allHosts;

    NSDictionary *filterSettings = @{
        kMTHNetworkTransactionFilterStatusCodeKey : @(statusCodes),
        kMTHNetworkTransactionFilterDeselectedInspectionKey : deselectedInspectionNameArray,
        kMTHNetworkTransactionFilterDeselectedHostKey : deselectedHosts,
    };
    [[NSUserDefaults standardUserDefaults] setObject:filterSettings forKey:kMTHNetworkTransactionsFilterSettingKey];
}

- (void)loadFilterSettingFromCache {
    NSDictionary *filterSetting = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kMTHNetworkTransactionsFilterSettingKey];
    MTHNetworkTransactionStatusCode statusCodes = [filterSetting[kMTHNetworkTransactionFilterStatusCodeKey] integerValue];
    NSSet *deselectedInspectionNameSet = [NSSet setWithArray:filterSetting[kMTHNetworkTransactionFilterDeselectedInspectionKey]];
    NSSet *deselectedHostSet = [NSSet setWithArray:filterSetting[kMTHNetworkTransactionFilterDeselectedHostKey]];

    // 恢复之前被取消选中的，确保新增的不会默认被过滤掉
    if (deselectedHostSet && deselectedHostSet.count) {
        for (NSInteger i = 0; i < self.hostFilterSection.rows.count; i++) {
            if ([deselectedHostSet containsObject:self.hosts[i]]) {
                self.hostFilterSection.rows[i].isSelected = NO;
            }
        }
    }

    if (deselectedInspectionNameSet && deselectedInspectionNameSet.count) {
        for (NSInteger i = 0; i < self.inspectionFilterSection.rows.count; i++) {
            if ([deselectedInspectionNameSet containsObject:self.inspections[i].name]) {
                self.inspectionFilterSection.rows[i].isSelected = NO;
            }
        }
    }

    if (statusCodes) {
        for (NSInteger i = 0; i < 6; i++) {
            if (i < 5) {
                self.statusFilterSection.rows[i].isSelected = statusCodes & (1 << i);
            } else {
                self.statusFilterSection.rows[i].isSelected
                    = !((statusCodes & MTHNetworkTransactionStatusCodeFailed) ^ MTHNetworkTransactionStatusCodeFailed);
            }
        }
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sections[section].rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([UITableViewCell class]) forIndexPath:indexPath];

    MTHNetworkMonitorFilterViewRow *row = self.sections[indexPath.section].rows[indexPath.row];
    cell.textLabel.text = row.title;
    cell.textLabel.font = [UIFont systemFontOfSize:13];
    cell.textLabel.textColor = [UIColor grayColor];
    cell.accessoryType = row.isSelected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 30.f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 35.f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 1.f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *sectionHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 35)];
    sectionHeaderView.backgroundColor = [UIColor colorWithRed:0.94 green:0.94 blue:0.96 alpha:1];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = self.sections[section].title;
    titleLabel.textColor = [UIColor darkGrayColor];

    UIButton *selectAllButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [selectAllButton setTitle:@"Select All" forState:UIControlStateNormal];
    [selectAllButton addTarget:self action:@selector(selectAllRow:) forControlEvents:UIControlEventTouchUpInside];
    selectAllButton.tag = section; // 以 Tag 来区分是哪个 Section 上的全选按钮
    UIButton *deselectAllButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [deselectAllButton setTitle:@"Deselect All" forState:UIControlStateNormal];
    [deselectAllButton addTarget:self action:@selector(deselectAllRow:) forControlEvents:UIControlEventTouchUpInside];
    deselectAllButton.tag = section; // 以 Tag 来区分是哪个 Section 上的全选按钮

    [sectionHeaderView addSubview:titleLabel];
    [sectionHeaderView addSubview:selectAllButton];
    [sectionHeaderView addSubview:deselectAllButton];
    titleLabel.frame = CGRectMake(10, 0, 200, 35);
    selectAllButton.frame = CGRectMake(self.view.frame.size.width - 95, 0, 85, 35);
    deselectAllButton.frame = CGRectMake(self.view.frame.size.width - 195, 0, 100, 35);


    return sectionHeaderView;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    MTHNetworkMonitorFilterViewRow *row = self.sections[indexPath.section].rows[indexPath.row];
    row.isSelected = !row.isSelected;
    cell.accessoryType = row.isSelected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - IBAction

- (void)selectAllRow:(id)sender {
    NSArray<MTHNetworkMonitorFilterViewSection *> *sectionsToSelect;
    if ([sender tag] != -1) {
        sectionsToSelect = @[ self.sections[[sender tag]] ];
    } else {
        sectionsToSelect = self.sections;
    }

    for (MTHNetworkMonitorFilterViewSection *section in sectionsToSelect) {
        for (MTHNetworkMonitorFilterViewRow *row in section.rows) {
            row.isSelected = YES;
        }
    }
    [self.tableView reloadData];
}

- (void)deselectAllRow:(id)sender {
    NSArray<MTHNetworkMonitorFilterViewSection *> *sectionsToDeselect;
    if ([sender tag] != -1) {
        sectionsToDeselect = @[ self.sections[[sender tag]] ];
    } else {
        sectionsToDeselect = self.sections;
    }

    for (MTHNetworkMonitorFilterViewSection *section in sectionsToDeselect) {
        for (MTHNetworkMonitorFilterViewRow *row in section.rows) {
            row.isSelected = NO;
        }
    }
    [self.tableView reloadData];
}

- (void)selectionDone:(id)sender {
    [self.navigationController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end

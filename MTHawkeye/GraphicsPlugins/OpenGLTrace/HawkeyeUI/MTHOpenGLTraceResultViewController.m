//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 30/06/2017
// Created by: EuanC
//


#import "MTHOpenGLTraceResultViewController.h"
#import "MTHOpenGLTraceHawkeyeAdaptor.h"
#import "MTHOpenGLTraceHawkeyeUI.h"
#import "MTHawkeyeUserDefaults+OpenGLTrace.h"

#import <inttypes.h>

#import <MTGLDebug/MTGLDebug.h>
#import <MTGLDebug/MTGLDebugObject+QuickLook.h>
#import <MTGLDebug/MTGLDebugObject.h>

#import <MTHawkeye/MTHMonitorChartView.h>
#import <MTHawkeye/MTHSimpleLineGraphView.h>
#import <MTHawkeye/MTHawkeyeClient.h>
#import <MTHawkeye/MTHawkeyeSettingViewController.h>
#import <MTHawkeye/MTHawkeyeStorage.h>
#import <MTHawkeye/UITableView+MTHEmptyTips.h>
#import <MTHawkeye/UIViewController+MTHawkeyeLayoutSupport.h>


#define MT_GL_BUFFER 0x99999999
#define MT_GL_PROGRAM 0x99999998
#define MT_GL_FRAMEBUFFER 0x99999997
#define MT_GL_TEXTURE 0x99999996

#define DIM(x) (sizeof(x) / sizeof(*(x)))

static const char *sizes[] = {"EiB", "PiB", "TiB", "GiB", "MiB", "KiB", "B"};
static const uint64_t exbibytes = 1024ULL * 1024ULL * 1024ULL * 1024ULL * 1024ULL * 1024ULL;

static NSString *calculateSize(uint64_t size) {
    uint64_t multiplier = exbibytes;
    int i;

    for (i = 0; i < DIM(sizes); i++, multiplier /= 1024) {
        if (size < multiplier)
            continue;
        if (size % multiplier == 0)
            return [NSString stringWithFormat:@"%" PRIu64 " %s", size / multiplier, sizes[i]];
        else
            return [NSString stringWithFormat:@"%.1f %s", (float)size / multiplier, sizes[i]];
    }
    return @"0";
}

@interface MTHOpenGLTraceResultViewController () <MTHOpenGLTraceDelegate, MTHMonitorChartViewDelegate, UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) UITableView *tableView;
@property (strong, nonatomic) MTHMonitorChartView *chartView;

@property (strong, nonatomic) MTHOpenGLTraceHawkeyeAdaptor *glTracer;

@property (nonatomic, copy) NSArray *alivingGLObjects;
@property (nonatomic, copy) NSArray *displayAliveGLObjects;

@property (nonatomic, strong) NSMutableArray *glMemoryUsedRecord;
@property (nonatomic, strong) NSMutableArray *glMemoryUsedRecordTimes;

@property (nonatomic, assign) BOOL underSelected;
@property (nonatomic, assign) NSRange selectedRange;

@end


@implementation MTHOpenGLTraceResultViewController

- (void)dealloc {
    [self.glTracer removeDelegate:self];
}

- (instancetype)init {
    if (self = [super init]) {
        self.glTracer = [[MTHawkeyeClient shared] pluginFromID:[MTHOpenGLTraceHawkeyeAdaptor pluginID]];
        [self.glTracer addDelegate:self];

        self.alivingGLObjects = self.glTracer.alivingMemoryGLObjects;
        self.displayAliveGLObjects = self.alivingGLObjects;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadData];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;

    self.view = self.tableView;

    CGRect frame = CGRectMake(0, 0, self.view.bounds.size.width, 180);
    self.chartView = [[MTHMonitorChartView alloc] initWithFrame:frame];
    self.chartView.delegate = self;
    self.chartView.unitLabelTitle = @"MB";

    self.tableView.tableHeaderView = self.chartView;

    self.title = @"OpenGL Memory Debugger";

    [self reloadTableViewFooter];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self reloadTableViewFooter];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];

#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_10_3
    if (@available(iOS 11.0, *)) {
    } else {
        UIEdgeInsets insets = UIEdgeInsetsMake([self mt_hawkeye_navigationBarTopLayoutGuide].length, 0, 0, 0);
        if (fabs(insets.top - self.tableView.contentInset.top) < DBL_EPSILON) {
            self.tableView.contentInset = insets;
            self.tableView.scrollIndicatorInsets = insets;
            self.tableView.contentOffset = CGPointMake(0, -insets.top);
        }
    }
#endif
}

- (void)reloadTableViewFooter {
    if (self.alivingGLObjects.count == 0) {
        if (![MTHawkeyeUserDefaults shared].openGLTraceOn) {
            [self.tableView mthawkeye_setFooterViewWithEmptyTips:@"OpenGL tracing is OFF"
                                                         tipsTop:45.f
                                                          button:@"Go to Setting"
                                                       btnTarget:self
                                                       btnAction:@selector(gotoSetting)];
        } else {
            [self.tableView mthawkeye_setFooterViewWithEmptyTips:@"Empty Records"];
        }
    } else {
        self.tableView.tableFooterView = [UIView new];
    }
}

- (void)loadData {
    NSArray<NSString *> *timeStamps;
    NSArray<NSString *> *glMemRecords;
    [[MTHawkeyeStorage shared] readKeyValuesInCollection:@"gl-mem" keys:&timeStamps values:&glMemRecords];
    if (timeStamps.count != glMemRecords.count) {
        return;
    }

    NSUInteger capacity = (timeStamps.lastObject.integerValue - timeStamps.firstObject.integerValue + 1);
    self.glMemoryUsedRecordTimes = [NSMutableArray arrayWithCapacity:capacity];
    self.glMemoryUsedRecord = [NSMutableArray arrayWithCapacity:capacity];
    double nextTimeStamp;
    double currentTimeStamp;
    double currentMemUsage;

    for (NSInteger i = 0; i < timeStamps.count; i++) {
        currentTimeStamp = [timeStamps[i] doubleValue];
        [self.glMemoryUsedRecordTimes addObject:@(currentTimeStamp)];
        [self.glMemoryUsedRecord addObject:@(glMemRecords[i].integerValue)];

        if (i == timeStamps.count - 1) {
            nextTimeStamp = [[NSDate date] timeIntervalSince1970];
        } else {
            nextTimeStamp = [timeStamps[i + 1] doubleValue];
        }
        currentMemUsage = [glMemRecords[i] doubleValue];

        NSInteger missedRecordCount = (NSInteger)(nextTimeStamp - [timeStamps[i] doubleValue] + 0.5) - 1;
        // 补全省略的记录
        for (NSInteger j = 0; j < missedRecordCount; j++) {
            nextTimeStamp = currentTimeStamp + j + 1;
            [self.glMemoryUsedRecordTimes addObject:@(nextTimeStamp)];
            [self.glMemoryUsedRecord addObject:@(currentMemUsage)];
        }
    }
}

// MARK: - MTHOpenGLMonitorDelegate
- (void)glTracer:(MTHOpenGLTraceHawkeyeAdaptor *)gltracer didUpdateMemoryUsed:(size_t)memorySizeInByte {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 选中状态时，不刷新 lineGraph
        if (!self.underSelected) {
            NSTimeInterval curTime = [[NSDate date] timeIntervalSince1970];
            [self.glMemoryUsedRecordTimes addObject:@(curTime)];
            [self.glMemoryUsedRecord addObject:@(memorySizeInByte / 1024.f / 1024.f)];
            [self.chartView reloadData];
        }
    });
}

- (void)glTracerDidUpdateAliveGLObjects:(MTHOpenGLTraceHawkeyeAdaptor *)gltracer {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *alvingGLObjects = gltracer.alivingMemoryGLObjects;
        BOOL countChanged = (self.alivingGLObjects.count != alvingGLObjects.count);
        self.alivingGLObjects = alvingGLObjects;

        if (self.underSelected) {
            // 无变化时，默认当做整个数组没有变动，减少重复计算
            if (countChanged) {
                self.displayAliveGLObjects = [self aliveGLObjectsBetweenIndexRange:self.selectedRange from:self.alivingGLObjects];
            }
        } else {
            self.displayAliveGLObjects = self.alivingGLObjects;
        }
        [self.tableView reloadData];
    });
}

// MARK: - MTHMonitorChartViewDelegate
- (NSInteger)numberOfPointsInChartView:(MTHMonitorChartView *)chartView {
    return self.glMemoryUsedRecord.count;
}

- (CGFloat)chartView:(MTHMonitorChartView *)chartView valueForPointAtIndex:(NSInteger)index {
    return [self.glMemoryUsedRecord[index] doubleValue];
}

- (BOOL)rangeSelectEnableForChartView:(MTHMonitorChartView *)chartView {
    return YES;
}

- (void)chartView:(MTHMonitorChartView *)chartView didSelectedWithIndexRange:(NSRange)indexRange {
    if ((indexRange.location == NSNotFound) || (indexRange.location == 0 && indexRange.length == self.glMemoryUsedRecord.count)) {
        self.underSelected = NO;
        self.displayAliveGLObjects = self.alivingGLObjects;
    } else {
        self.underSelected = YES;
        self.selectedRange = indexRange;
        self.displayAliveGLObjects = [self aliveGLObjectsBetweenIndexRange:indexRange from:self.alivingGLObjects];
    }

    [self.tableView reloadData];
}

- (NSArray *)aliveGLObjectsBetweenIndexRange:(NSRange)indexRange from:(NSArray *)objects {
    if (!indexRange.length) {
        return @[];
    }

    NSUInteger leftIndex = indexRange.location;
    NSUInteger rightIndex = indexRange.location + indexRange.length;
    double startTime = 0.f, endTime = 0.f;
    if ((leftIndex < self.glMemoryUsedRecordTimes.count - 1) && (leftIndex > 0)) {
        startTime = [self.glMemoryUsedRecordTimes[leftIndex > 1 ? leftIndex - 1 : 0] doubleValue];
    }

    if (rightIndex <= self.glMemoryUsedRecordTimes.count - 1) {
        endTime = [self.glMemoryUsedRecordTimes[rightIndex] doubleValue];
    }

    if ((startTime > 0.f || (startTime < DBL_EPSILON && leftIndex == 0)) && endTime > 0.f) {
        return [self aliveGLObjectsBetweenStartTime:startTime endTime:endTime from:objects];
    } else {
        return [objects copy];
    }
}

- (NSArray *)aliveGLObjectsBetweenStartTime:(double)startTime endTime:(double)endTime from:(NSArray *)objects {
    NSMutableArray *tmp = [NSMutableArray array];
    for (NSInteger i = 0; i < objects.count; ++i) {
        MTGLDebugCVObject *debug = objects[i];
        if (debug && [debug isKindOfClass:[MTGLDebugObject class]]) {
            if (debug.timestampInDouble >= startTime && debug.timestampInDouble <= endTime) {
                [tmp addObject:debug];
            }
        }
    }
    return [tmp copy];
}

// MARK: - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.displayAliveGLObjects.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"Living OpenGL Objects";
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if (section == 0) {
        ((UITableViewHeaderFooterView *)view).textLabel.text = @"Living OpenGL Objects";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"glActiveObjectCell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"glActiveObjectCell"];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    if (indexPath.row < self.displayAliveGLObjects.count) {
        MTGLDebugObject *activeGLObject = self.displayAliveGLObjects[indexPath.row];
        NSString *sizeInfo = calculateSize(activeGLObject.memorySize);
        NSString *title = [NSString stringWithFormat:@"%@ (%@)", [activeGLObject targetString], sizeInfo];
        cell.textLabel.text = title;

        NSMutableString *detail = [NSMutableString string];
        [detail appendFormat:@"time:%@, ", activeGLObject.timestamp];

        if ([activeGLObject isKindOfClass:[MTGLDebugTextureObject class]]) {
            MTGLDebugTextureObject *textureObj = (MTGLDebugTextureObject *)activeGLObject;
            [detail appendFormat:@"(w:%@, h:%@), ", @(textureObj.width), @(textureObj.height)];
        }
        if (activeGLObject.object > 0) {
            [detail appendFormat:@"GLuint:%@, ", @(activeGLObject.object)];
        }
        cell.detailTextLabel.text = [detail copy];

#if 0
        if (1 /* 当前还不支持查看一个 GL 对象是否被其他线程修改，待 GLDebug 支持*/) {

        } else {
            id quickLookObj = [activeGLObject debugQuickLookObject];
            if ([quickLookObj isKindOfClass:[UIImage class]]) {
                UIImageView *imgView = [[UIImageView alloc] initWithImage:[quickLookObj copy]];
                imgView.frame = CGRectMake(0, 0, 40, 40);
                cell.accessoryView = imgView;
            } else {
                cell.accessoryView = nil;
            }
        }
#endif
    } else {
        cell.textLabel.text = @"";
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[tableView cellForRowAtIndexPath:indexPath] setSelected:NO animated:YES];
}

// MARK: - Utils
- (void)gotoSetting {
    MTHawkeyeSettingTableEntity *entity = [[MTHawkeyeSettingTableEntity alloc] init];
    entity.sections = [(MTHawkeyeSettingFoldedCellEntity *)[MTHOpenGLTraceHawkeyeUI settings] foldedSections];

    MTHawkeyeSettingViewController *vc = [[MTHawkeyeSettingViewController alloc] initWithTitle:@"OpenGL Debug" viewModelEntity:entity];
    [self.navigationController pushViewController:vc animated:YES];
}

@end

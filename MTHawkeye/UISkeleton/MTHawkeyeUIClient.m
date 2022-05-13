//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/4
// Created by: EuanC
//


#import "MTHawkeyeUIClient.h"
#import "MTHFloatingMonitorWindow.h"
#import "MTHMonitorView.h"
#import "MTHMonitorViewConfiguration.h"
#import "MTHawkeyeBuildinFloatingWidget.h"
#import "MTHawkeyeClient.h"
#import "MTHawkeyeFloatingWidgetViewController.h"
#import "MTHawkeyeFloatingWidgets.h"
#import "MTHawkeyeMainPanelSwitchViewController.h"
#import "MTHawkeyeMainPanelViewController.h"
#import "MTHawkeyeMainPanels.h"
#import "MTHawkeyeSettingUIEntity.h"
#import "MTHawkeyeSettingViewController.h"
#import "MTHawkeyeUserDefaults+UISkeleton.h"

#import <MTHawkeye/MTHawkeyeLogMacros.h>
#import <MTHawkeye/MTHawkeyeUtility.h>
#import <MTHawkeye/UIViewController+MTHawkeyeCurrentViewController.h>

#import <pthread/pthread.h>

#if defined(__IPHONE_13_0)
#define MTH_AT_LEAST_IOS13_SDK (__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0)
#else
#define MTH_AT_LEAST_IOS13_SDK NO
#endif

NSString *const kMTHawkeyeUIGroupMemory = @"Memory";
NSString *const kMTHawkeyeUIGroupTimeConsuming = @"TimeConsuming";
NSString *const kMTHawkeyeUIGroupEnergy = @"Energy";
NSString *const kMTHawkeyeUIGroupNetwork = @"Network";
NSString *const kMTHawkeyeUIGroupGraphics = @"Graphics";
NSString *const kMTHawkeyeUIGroupStorage = @"Storage";
NSString *const kMTHawkeyeUIGroupUtility = @"Utility";


const NSString *kMTHFloatingWidgetRaiseWarningParamsKeepDurationKey = @"keep-duration";
const NSString *kMTHFloatingWidgetRaiseWarningParamsPanelIDKey = @"related-panel-id";

@interface MTHawkeyeUIClient () <MTHawkeyePlugin, MTHFloatingMonitorWindowDelegate, MTHawkeyeFloatingWidgetViewControllerDatasource, MTHawkeyeFloatingWidgetViewControllerDelegate>

@property (nonatomic, copy) MTHawkeyeUIClientPluginsSetupHandler pluginsSetupHandler;
@property (nonatomic, copy) MTHawkeyeUIClientPluginsCleanHandler pluginsCleanHandler;
@property (nonatomic, assign) BOOL pluginsDidSetup;
@property (nonatomic, assign) BOOL pluginsDidClean;

@property (nonatomic, assign) BOOL floatingWidgetsDataBuild;

@property (nonatomic, strong) MTHawkeyeSettingUIEntity *settingPlugins;
@property (nonatomic, strong) MTHawkeyeFloatingWidgets *floatingWidgets;
@property (nonatomic, strong) MTHawkeyeMainPanels *mainPanels;

@property (nonatomic, strong) MTHawkeyeFloatingWidgetViewController *floatingWidgetVC;
@property (nonatomic, strong) MTHFloatingMonitorWindow *monitorWindow;

@property (nonatomic, strong) UISwipeGestureRecognizer *swipeGestureRecognizer;
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGestureRecognizer;

@property (nonatomic, weak) UIViewController *currentExpandController;
@property (nonatomic, assign) UIStatusBarStyle cachedStatusBarStyle;
@property (nonatomic, weak) UIWindow *previousKeyWindow;

@property (nonatomic, strong) NSMutableArray<NSString *> *warningRelatedPanelIDs;

@property (nonatomic, assign) BOOL observingWindow;

@property (nonatomic, strong) MTHawkeyeMemoryStatFloatingWidget *buildInMemFloatingWidget;
@property (nonatomic, strong) MTHawkeyeCPUStatFloatingWidget *buildInCPUFloatingWidget;

@end


@implementation MTHawkeyeUIClient

- (void)dealloc {
    [self unobserveHawkeyeSettings];
}

+ (instancetype)shared {
    static MTHawkeyeUIClient *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });

    return _sharedInstance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _floatingWidgetsDataBuild = NO;

        _warningRelatedPanelIDs = @[].mutableCopy;

        [self observeHawkeyeSettings];
    }
    return self;
}

// MARK: -

- (void)observeHawkeyeSettings {
    __weak __typeof(self) weakSelf = self;
    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(hawkeyeOn))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                if ([newValue boolValue]) {
                    [weakSelf startServer];
                } else {
                    [weakSelf stopServer];
                }
            }];

    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(displayFloatingWindow))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                if ([newValue boolValue])
                    [weakSelf startServer];
                else
                    [weakSelf stopServer];
            }];

    [[MTHawkeyeUserDefaults shared]
        mth_addObserver:self
                 forKey:NSStringFromSelector(@selector(floatingWindowShowHideGesture))
            withHandler:^(id _Nullable oldValue, id _Nullable newValue) {
                if ([newValue boolValue])
                    [weakSelf setupShowHideGestureOnWindow:[weakSelf theWindow]];
                else
                    [weakSelf removeShowHideGestureOn:[weakSelf theWindow]];
            }];
}

- (void)unobserveHawkeyeSettings {
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(hawkeyeOn))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(displayFloatingWindow))];
    [[MTHawkeyeUserDefaults shared] mth_removeObserver:self forKey:NSStringFromSelector(@selector(floatingWindowShowHideGesture))];
}

// MARK: - start / stop service

- (void)setPluginsSetupHandler:(MTHawkeyeUIClientPluginsSetupHandler)pluginsSetup
           pluginsCleanHandler:(MTHawkeyeUIClientPluginsCleanHandler)pluginsCleaner {
    self.pluginsSetupHandler = pluginsSetup;
    self.pluginsCleanHandler = pluginsCleaner;
}

- (void)startServer {
    if ([MTHawkeyeUtility underUnitTest] || ![MTHawkeyeUserDefaults shared].hawkeyeOn || ![MTHawkeyeUserDefaults shared].displayFloatingWindow)
        return;

    [[MTHawkeyeClient shared] addPlugin:self];

    [self setupUIPlugins];
    [self showWindow];
    [self observeTheWindow];

    MTHLogInfo(@"HawkeyeUIClient start");
}

- (void)stopServer {
    if ([MTHawkeyeUtility underUnitTest])
        return;

    [[MTHawkeyeClient shared] removePlugin:self];

    [self removeWindow];

    [self stopObserveTheWindow];

    // release memory
    if (_currentExpandController) {
        [_currentExpandController dismissViewControllerAnimated:YES completion:nil];
        _currentExpandController = nil;
    }

    [self cleanUIPlugins];

    MTHLogInfo(@"HawkeyeUIClient stop");

    // keep the show/hide gesture
}

- (void)setupUIPlugins {
    if (self.pluginsSetupHandler && !self.pluginsDidSetup) {
        self.pluginsDidClean = NO;
        self.pluginsDidSetup = YES;

        NSMutableArray<id<MTHawkeyeMainPanelPlugin>> *mainPanelPlugins = @[].mutableCopy;
        NSMutableArray<id<MTHawkeyeFloatingWidgetPlugin>> *floatingWidgetPlugins = @[].mutableCopy;

        [self buildinFloatingWidgetPluginsSetup:floatingWidgetPlugins];

        NSMutableArray<id<MTHawkeyeSettingUIPlugin>> *defaultSettingUIPluginsInto = @[].mutableCopy;

        self.pluginsSetupHandler(mainPanelPlugins, floatingWidgetPlugins, defaultSettingUIPluginsInto);

        self.mainPanels = [[MTHawkeyeMainPanels alloc] initWithMainPanelPlugins:mainPanelPlugins.copy];
        self.floatingWidgets = [[MTHawkeyeFloatingWidgets alloc] initWithWidgets:floatingWidgetPlugins.copy];
        self.settingPlugins = [[MTHawkeyeSettingUIEntity alloc] initWithSettingPlugins:defaultSettingUIPluginsInto floatingWidgetSwitchers:floatingWidgetPlugins];
    }
}

- (void)cleanUIPlugins {
    if (self.pluginsCleanHandler && !self.pluginsDidClean) {
        self.pluginsDidClean = YES;
        self.pluginsDidSetup = NO;

        NSMutableArray *mainPanels = self.mainPanels.panels;
        NSMutableArray *floatingWidgets = self.floatingWidgets.plugins;
        NSMutableArray *settingPlugins = self.settingPlugins.plugins;
        self.pluginsCleanHandler(mainPanels, floatingWidgets, settingPlugins);

        [self buildinFloatingWidgetPluginsClean:floatingWidgets];

        if (mainPanels.count == 0)
            self.mainPanels = nil;
        else
            self.mainPanels = [[MTHawkeyeMainPanels alloc] initWithMainPanelPlugins:mainPanels.copy];

        if (floatingWidgets.count == 0)
            self.floatingWidgets = nil;
        else
            self.floatingWidgets = [[MTHawkeyeFloatingWidgets alloc] initWithWidgets:floatingWidgets.copy];

        if (floatingWidgets.count == 0 && settingPlugins.count == 0)
            self.settingPlugins = nil;
        else
            self.settingPlugins = [[MTHawkeyeSettingUIEntity alloc] initWithSettingPlugins:settingPlugins.copy floatingWidgetSwitchers:floatingWidgets.copy];
    }
}

- (void)buildinFloatingWidgetPluginsSetup:(NSMutableArray<id<MTHawkeyeFloatingWidgetPlugin>> *)floatingWidgetPlugins {
    self.buildInMemFloatingWidget = [[MTHawkeyeMemoryStatFloatingWidget alloc] init];
    self.buildInCPUFloatingWidget = [[MTHawkeyeCPUStatFloatingWidget alloc] init];
    [floatingWidgetPlugins addObject:self.buildInMemFloatingWidget];
    [floatingWidgetPlugins addObject:self.buildInCPUFloatingWidget];
}

- (void)buildinFloatingWidgetPluginsClean:(NSMutableArray *)floatingWidgets {
    [floatingWidgets removeObject:self.buildInMemFloatingWidget];
    [floatingWidgets removeObject:self.buildInCPUFloatingWidget];
    self.buildInMemFloatingWidget = nil;
    self.buildInCPUFloatingWidget = nil;
}

// MARK: - Modal Presentation and Window Management
- (void)makeKeyAndPresentViewController:(UIViewController *)viewController animated:(BOOL)animated completion:(void (^)(void))completion {
    // Save the current key window so we can restore it following dismissal.
    self.previousKeyWindow = [[UIApplication sharedApplication] keyWindow];

    // Make our window key to correctly handle input.
    [self.monitorWindow makeKeyWindow];

    // Move the status bar on top of FLEX so we can get scroll to top behavior for taps.
    [[self statusWindow] setWindowLevel:self.monitorWindow.windowLevel + 1.0];

    // If this app doesn't use view controller based status bar management and we're on iOS 7+,
    // make sure the status bar style is UIStatusBarStyleDefault. We don't actully have to check
    // for view controller based management because the global methods no-op if that is turned on.
    self.cachedStatusBarStyle = [[UIApplication sharedApplication] statusBarStyle];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];

    self.currentExpandController = viewController;

    // Show the view controller.
    [self.floatingWidgetVC presentViewController:self.currentExpandController animated:animated completion:completion];
}

- (void)resignKeyAndDismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion {
    if (self.previousKeyWindow) {
        UIWindow *previousKeyWindow = self.previousKeyWindow;
        self.previousKeyWindow = nil;
        [previousKeyWindow makeKeyWindow];
        [[previousKeyWindow rootViewController] setNeedsStatusBarAppearanceUpdate];

        // Restore the status bar window's normal window level.
        // We want it above FLEX while a modal is presented for scroll to top, but below FLEX otherwise for exploration.
        [[self statusWindow] setWindowLevel:UIWindowLevelStatusBar];

        // Restore the stauts bar style if the app is using global status bar management.
        [[UIApplication sharedApplication] setStatusBarStyle:self.cachedStatusBarStyle];
    }

    if (self.currentExpandController) {
        [self.currentExpandController dismissViewControllerAnimated:animated completion:completion];
        self.currentExpandController = nil;
    }
}

- (UIWindow *)statusWindow {
    NSString *statusBarString = [NSString stringWithFormat:@"%@arWindow", @"_statusB"];
    return [[UIApplication sharedApplication] valueForKey:statusBarString];
}

// MARK: - MTHFloatingMonitorWindowDelegate
- (BOOL)shouldPointBeHandled:(CGPoint)point {
    if (self.floatingWidgetVC.presentedViewController != nil) {
        return CGRectContainsPoint(self.floatingWidgetVC.presentedViewController.view.frame, point);
    } else {
        return CGRectContainsPoint(self.floatingWidgetVC.monitorView.frame, point);
    }
}

- (BOOL)canBecomeKeyWindow {
    return self.previousKeyWindow != nil;
}

// MARK: - MTHawkeyeFloatingWidgetViewControllerDatasource
- (NSInteger)floatingWidgetCellCount {
    return [self.floatingWidgets floatingWidgetCellCount];
}

- (MTHMonitorViewCell *)floatingWidgetCellAtIndex:(NSUInteger)index {
    return [self.floatingWidgets floatingWidgetCellAtIndex:index];
}

// MARK: - MTHawkeyeFloatingWidgetViewControllerDelegate

- (void)floatingWidgetDidTapped {
    NSString *gotoPanel = nil;
    @synchronized(self.warningRelatedPanelIDs) {
        gotoPanel = self.warningRelatedPanelIDs.lastObject;
    }
    [self openMainPanelWithSelectedPanelID:gotoPanel];
}

- (void)openMainPanelWithSelectedPanelID:(NSString *)panelID {
    if (self.currentExpandController)
        return;

    MTHawkeyeMainPanelViewController *vc = [[MTHawkeyeMainPanelViewController alloc] initWithSelectedPanelID:panelID
                                                                                                  datasource:self.mainPanels
                                                                                                    delegate:self.mainPanels];
    vc.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(quitBtnTapped)];

    UINavigationController *nv = [[UINavigationController alloc] initWithRootViewController:vc];
    [self makeKeyAndPresentViewController:nv animated:YES completion:nil];
}

- (void)quitBtnTapped {
    [self resignKeyAndDismissViewControllerAnimated:NO completion:nil];
}

// MARK: - show & hide

- (void)showWindow {
    MTHLogInfo(@"will show window");
    if (!self.monitorWindow.hidden)
        return;

    self.monitorWindow.hidden = NO;
#if MTH_AT_LEAST_IOS13_SDK
    if (@available(iOS 13.0, *)) {
        // Fix: Swift project missing scene
        if (!self.monitorWindow.windowScene) {
            self.monitorWindow.windowScene = (UIWindowScene *)UIApplication.sharedApplication.connectedScenes.anyObject;
        }
        // Try to find the active scene
        if (self.monitorWindow.windowScene.activationState != UISceneActivationStateForegroundActive) {
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                // Look for an active UIWindowScene
                if (scene.activationState == UISceneActivationStateForegroundActive &&
                    [scene isKindOfClass:[UIWindowScene class]]) {
                    self.monitorWindow.windowScene = (UIWindowScene *)scene;
                    break;
                }
            }
        }
    }
#endif

    if (!self.floatingWidgetsDataBuild) {
        [self.floatingWidgets rebuildDatasource];
        self.floatingWidgetsDataBuild = YES;
    }

    [self.floatingWidgetVC reloadData];

    MTHLogInfo(@"show hawkeye window");
}

- (void)hideWindow {
    if (self.monitorWindow.hidden)
        return;

    self.monitorWindow.hidden = YES;

    MTHLogInfo(@"hide hawkeye window");
}

- (void)showMainPanelWithSelectedID:(NSString *)mainPanelId {
    [self openMainPanelWithSelectedPanelID:mainPanelId];
}

- (void)raiseWarningOnFloatingWidget:(NSString *)floatingWidgetID
                          withParams:(NSDictionary *)params {
    id<MTHawkeyeFloatingWidgetPlugin> plugin = [self.floatingWidgets widgetFromID:floatingWidgetID];
    if ([plugin respondsToSelector:@selector(receivedRaiseWarningCommand:)])
        [plugin receivedRaiseWarningCommand:params];

    if (![params isKindOfClass:[NSDictionary class]])
        return;

    CGFloat duration = [params[kMTHFloatingWidgetRaiseWarningParamsKeepDurationKey] floatValue];
    NSString *warningRelatedPanelID = params[kMTHFloatingWidgetRaiseWarningParamsPanelIDKey];

    @synchronized(self.warningRelatedPanelIDs) {
        [self.warningRelatedPanelIDs addObject:warningRelatedPanelID];
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        @synchronized(self.warningRelatedPanelIDs) {
            if (self.warningRelatedPanelIDs.count > 0)
                [self.warningRelatedPanelIDs removeObjectAtIndex:0];
        }
    });
}

- (void)removeWindow {
    if (_floatingWidgetVC.presentedViewController) {
        [_floatingWidgetVC.presentedViewController dismissViewControllerAnimated:NO completion:nil];
    }

    _monitorWindow.rootViewController = nil;
    [_monitorWindow resignKeyWindow];
    [_monitorWindow removeFromSuperview];
    _monitorWindow = nil;

    _floatingWidgetVC = nil;
    _floatingWidgetsDataBuild = NO;

    MTHLogInfo(@"remove hawkeye window");
}

- (UIWindow *)theWindow {
    id<UIApplicationDelegate> appDelegate = [UIApplication sharedApplication].delegate;
    UIWindow *theWindow = nil;

    // 有些 App 可能删除了 AppDelegate 暴露的 window 属性
    if ([appDelegate respondsToSelector:@selector(window)]) {
        theWindow = [[UIApplication sharedApplication].delegate window];
    } else {
        theWindow = [UIApplication sharedApplication].keyWindow;
    }
    return theWindow;
}

- (void)setupShowHideGestureOnWindow:(UIWindow *)theWindow {
    if (!self.swipeGestureRecognizer || ![theWindow.gestureRecognizers containsObject:self.swipeGestureRecognizer]) {
        self.swipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(showhideSwipeGestureHandler:)];
        self.swipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
        self.swipeGestureRecognizer.numberOfTouchesRequired = 3;
        [theWindow addGestureRecognizer:self.swipeGestureRecognizer];

        MTHLogInfo(@"setup floating widgets show & hide swipe gesture");
    }

    if (!self.longPressGestureRecognizer || ![theWindow.gestureRecognizers containsObject:self.longPressGestureRecognizer]) {
        self.longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(showhideSwipeGestureHandler:)];
        self.longPressGestureRecognizer.numberOfTouchesRequired = 3;
        self.longPressGestureRecognizer.minimumPressDuration = 2.f;
        [theWindow addGestureRecognizer:self.longPressGestureRecognizer];

        MTHLogInfo(@"setup floating widgets show & hide long press gesture");
    }
}

- (void)removeShowHideGestureOn:(UIWindow *)theWindow {
    if (self.swipeGestureRecognizer && self.longPressGestureRecognizer) {
        [theWindow removeGestureRecognizer:self.swipeGestureRecognizer];
        [theWindow removeGestureRecognizer:self.longPressGestureRecognizer];
        MTHLogInfo(@"remove floating widgets show & hide gesture");
    }
}

- (void)showhideSwipeGestureHandler:(UIGestureRecognizer *)gesture {
    BOOL triggered = NO;
    if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]]) {
        if (gesture.state == UIGestureRecognizerStateBegan) {
            triggered = YES;
        }
    } else if ([gesture isKindOfClass:[UISwipeGestureRecognizer class]]) {
        triggered = YES;
    }

    if (triggered) {
        BOOL isDisplay = [MTHawkeyeUserDefaults shared].hawkeyeOn && [MTHawkeyeUserDefaults shared].displayFloatingWindow;
        [MTHawkeyeUserDefaults shared].displayFloatingWindow = !isDisplay;

        if ([MTHawkeyeUserDefaults shared].displayFloatingWindow) {
            [self showSettingViewIfNeed];
        }
    }
}

- (void)showSettingViewIfNeed {
    // once the floating widgets is empty, navigate to setting view.
    if ([self.floatingWidgets floatingWidgetCellCount] == 0 || ![MTHawkeyeUserDefaults shared].hawkeyeOn) {
        [self setupUIPlugins];

        MTHawkeyeSettingTableEntity *entity = [[MTHawkeyeUIClient shared].settingPlugins settingViewModelEntity];
        MTHawkeyeSettingViewController *vc = [[MTHawkeyeSettingViewController alloc] initWithTitle:@"Setting" viewModelEntity:entity];

        self.cachedStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];

        vc.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(quitBtnTapped)];

        UINavigationController *nv = [[UINavigationController alloc] initWithRootViewController:vc];
        [[UIViewController mth_topViewController] presentViewController:nv animated:YES completion:nil];
        self.currentExpandController = nv;
    }
}

- (void)setCurrentExpandController:(UIViewController *)currentExpandController {
    _currentExpandController = currentExpandController;
    _currentExpandController.modalPresentationStyle = UIModalPresentationFullScreen;
}

// MARK: -

static void *WindowKVOContext = &WindowKVOContext;

- (void)observeTheWindow {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.observingWindow)
            return;

        id appDelegate = [UIApplication sharedApplication].delegate;
        [appDelegate addObserver:self forKeyPath:NSStringFromSelector(@selector(window)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:WindowKVOContext];

        self.observingWindow = YES;
    });
}

- (void)stopObserveTheWindow {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.observingWindow)
            return;

        id appDelegate = [UIApplication sharedApplication].delegate;
        @try {
            [appDelegate removeObserver:self forKeyPath:NSStringFromSelector(@selector(window)) context:&WindowKVOContext];
        } @catch (NSException *__unused exception) {
        }

        self.observingWindow = NO;
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context {
    if (pthread_main_np() == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        });
        return;
    }

    if (context == WindowKVOContext && [keyPath isEqualToString:NSStringFromSelector(@selector(window))]) {
        if ([MTHawkeyeUserDefaults shared].floatingWindowShowHideGesture)
            [self setupShowHideGestureOnWindow:[self theWindow]];
    }
}

// MARK: - MTHawkeyePlugin
+ (NSString *)pluginID {
    return @"hawkeye-ui-client";
}

- (void)hawkeyeClientDidStart {
    // do nothing.
}

- (void)hawkeyeClientDidStop {
    // do nothing.
}

- (void)receivedFlushStatusCommand {
    [self.floatingWidgets receivedFlushStatusCommand];
}

// MARK: - getter
- (MTHFloatingMonitorWindow *)monitorWindow {
    if (_monitorWindow == nil) {
        _monitorWindow = [[MTHFloatingMonitorWindow alloc] initWithRootViewController:self.floatingWidgetVC];
        _monitorWindow.eventDelegate = self;
        _monitorWindow.hidden = YES;
    }
    return _monitorWindow;
}

- (MTHawkeyeFloatingWidgetViewController *)floatingWidgetVC {
    if (_floatingWidgetVC == nil) {
        _floatingWidgetVC = [[MTHawkeyeFloatingWidgetViewController alloc] init];
        _floatingWidgetVC.datasource = self;
        self.floatingWidgets.delegate = _floatingWidgetVC;
        _floatingWidgetVC.delegate = self;
    }
    return _floatingWidgetVC;
}

@end

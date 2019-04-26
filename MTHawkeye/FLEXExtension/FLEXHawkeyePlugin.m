//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/10
// Created by: EuanC
//


#import "FLEXHawkeyePlugin.h"
#import "MTHawkeyeHooking.h"

#import <FLEX/FLEX.h>
#import <FLEX/FLEXFileBrowserTableViewController.h>

@interface FLEXHawkeyePlugin ()

@end


@implementation FLEXHawkeyePlugin

// MARK: - MTHawkeyeMainPanelPlugin

- (NSString *)groupNameSwitchingOptionUnder {
    return kMTHawkeyeUIGroupUtility;
}

- (NSString *)switchingOptionTitle {
    return @"FLEX";
}

- (BOOL)switchingOptionTriggerCustomAction {
    return YES;
}

- (void)switchingOptionDidTapped {
    [FLEXHawkeyePlugin addAirDropMenuForFileBrowserViewController];
    [self showFLEX];
}

// MARK: -
- (void)showFLEX {
    [[FLEXManager sharedManager] showExplorer];
}

+ (void)addAirDropMenuForFileBrowserViewController {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [FLEXHawkeyePlugin extendMenuItems];
        [FLEXHawkeyePlugin extendPerformAction];
        [FLEXHawkeyePlugin extendBrowserTableViewCell];
    });
}

+ (void)extendMenuItems {
    /*
     FLEXFileBrowserTableViewController
     replace

     - (void)viewDidLoad
     {
     [super viewDidLoad];

     UIMenuItem *renameMenuItem = [[UIMenuItem alloc] initWithTitle:@"Rename" action:@selector(fileBrowserRename:)];
     UIMenuItem *deleteMenuItem = [[UIMenuItem alloc] initWithTitle:@"Delete" action:@selector(fileBrowserDelete:)];
     UIMenuItem *airDropMenuItem = [[UIMenuItem alloc] initWithTitle:@"AirDrop" action:@selector(fileAirDrop:)];
     [UIMenuController sharedMenuController].menuItems = @[renameMenuItem, deleteMenuItem, airDropMenuItem];
     }
     */

    SEL sel = @selector(viewDidLoad);
    SEL swzSel = [MTHawkeyeHooking swizzledSelectorForSelector:sel];

    void (^swzBlock)(id) = ^void(id obj) {
        ((void (*)(id, SEL))objc_msgSend)(obj, swzSel);
        NSMutableArray<UIMenuItem *> *items = [[UIMenuController sharedMenuController].menuItems mutableCopy];
        for (UIMenuItem *item in items) {
            if ([item.title isEqualToString:@"AirDrop"]) {
                return;
            }
        }

        UIMenuItem *airDropMenuItem = [[UIMenuItem alloc] initWithTitle:@"AirDrop" action:NSSelectorFromString(@"fileAirDrop:")];
        [items addObject:airDropMenuItem];
        [UIMenuController sharedMenuController].menuItems = [items copy];
    };
    [MTHawkeyeHooking replaceImplementationOfKnownSelector:sel onClass:FLEXFileBrowserTableViewController.class withBlock:swzBlock swizzledSelector:swzSel];
}

+ (void)extendPerformAction {
    /*
     FLEXFileBrowserTableViewController
     replace

     - (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
     {
     return action == @selector(fileBrowserDelete:) || action == @selector(fileBrowserRename:) || action == @selector(fileAirDrop:);
     }

     - (void)fileAirDrop:(UITableViewCell *)sender
     {
     NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
     NSString *fullPath = [self filePathAtIndexPath:indexPath];

     [self openFileController:fullPath];
     }
     */

    SEL performSel = @selector(tableView:canPerformAction:forRowAtIndexPath:withSender:);
    SEL performSwzSel = [MTHawkeyeHooking swizzledSelectorForSelector:performSel];

    BOOL (^performSwzBlock)(id, UITableView *, SEL, NSIndexPath *, id) = ^BOOL(id obj, UITableView *tableView, SEL action, NSIndexPath *indexPath, id sender) {
        BOOL resp = ((BOOL(*)(id, SEL, UITableView *, SEL, NSIndexPath *, id))objc_msgSend)(obj, performSwzSel, tableView, action, indexPath, sender);
        if (!resp && action == NSSelectorFromString(@"fileAirDrop:")) {
            resp = YES;
        }
        return resp;
    };
    [MTHawkeyeHooking replaceImplementationOfKnownSelector:performSel onClass:FLEXFileBrowserTableViewController.class withBlock:performSwzBlock swizzledSelector:performSwzSel];

    ///
    SEL sel = NSSelectorFromString(@"fileAirDrop:");
    void (^swzBlock)(id, UITableViewCell *) = ^(UITableViewController *obj, UITableViewCell *sender) {
        NSIndexPath *indexPath = [obj.tableView indexPathForCell:sender];
        if (!indexPath) return;

        SEL filepathSel = NSSelectorFromString(@"filePathAtIndexPath:");
        SEL openfileSel = NSSelectorFromString(@"openFileController:");
        if (!filepathSel || !openfileSel) return;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSString *fullPath = [obj performSelector:filepathSel withObject:indexPath];
        [obj performSelector:openfileSel withObject:fullPath];
#pragma clang diagnostic pop
    };
    IMP imp = imp_implementationWithBlock(swzBlock);
    class_addMethod(FLEXFileBrowserTableViewController.class, sel, imp, "@@:@");
}

+ (void)extendBrowserTableViewCell {
    /*
     FLEXFileBrowserTableViewCell
     add

     - (void)fileBrowserDelete:(UIMenuController *)sender
     {
     id target = [self.nextResponder targetForAction:_cmd withSender:sender];
     [[UIApplication sharedApplication] sendAction:_cmd to:target from:self forEvent:nil];
     }
     */

    Class cls = NSClassFromString(@"FLEXFileBrowserTableViewCell");
    if (!cls) // for dynamic framework
        cls = NSClassFromString(@"PodMTHawkeye_FLEXFileBrowserTableViewCell");
    if (!cls)
        return;

    SEL sel = NSSelectorFromString(@"fileAirDrop:");
    void (^swzBlock)(id, UIMenuController *) = ^(UIViewController *obj, UIMenuController *sender) {
        id target = [obj.nextResponder targetForAction:sel withSender:sender];
        if (!target) return;
        [[UIApplication sharedApplication] sendAction:sel to:target from:obj forEvent:nil];
    };
    IMP imp = imp_implementationWithBlock(swzBlock);
    class_addMethod(cls, sel, imp, "@@:@");
}

@end

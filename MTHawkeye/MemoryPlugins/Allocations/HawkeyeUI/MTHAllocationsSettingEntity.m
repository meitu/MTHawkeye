//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/12/18
// Created by: EuanC
//


#import "MTHAllocationsSettingEntity.h"
#import "MTHawkeyeUserDefaults+Allocations.h"

@implementation MTHAllocationsSettingEntity

+ (MTHawkeyeSettingSwitcherCellEntity *)loggerSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *entity = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    entity.title = @"Trace Heap & VM Allocations";
    entity.setupValueHandler = ^BOOL {
        return [MTHawkeyeUserDefaults shared].allocationsTraceOn;
    };
    entity.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (newValue != [MTHawkeyeUserDefaults shared].allocationsTraceOn) {
            [MTHawkeyeUserDefaults shared].allocationsTraceOn = newValue;
        }
        return YES;
    };
    return entity;
}

+ (MTHawkeyeSettingSwitcherCellEntity *)includeSystemFrameSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *entity = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    entity.title = @"Trace System Libraries Frames";
    entity.setupValueHandler = ^BOOL {
        return [MTHawkeyeUserDefaults shared].isStackLogNeedSysFrame;
    };
    entity.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (newValue != [MTHawkeyeUserDefaults shared].isStackLogNeedSysFrame) {
            [MTHawkeyeUserDefaults shared].isStackLogNeedSysFrame = newValue;
        }
        return YES;
    };
    return entity;
}

+ (MTHawkeyeSettingEditorCellEntity *)mallocReportThresholdEditorCell {
    MTHawkeyeSettingEditorCellEntity *editor = [[MTHawkeyeSettingEditorCellEntity alloc] init];
    editor.title = @"Heap Report Threshold";
    editor.inputTips = @"Only m(*)alloc records that accumulate greater than the threshold will be output to the report.";
    editor.editorKeyboardType = UIKeyboardTypeNumberPad;
    editor.valueUnits = @"KB";
    editor.setupValueHandler = ^NSString *_Nonnull {
        NSInteger threshold = [MTHawkeyeUserDefaults shared].mallocReportThresholdInBytes / 1024;
        NSString *str = [NSString stringWithFormat:@"%@", @(threshold)];
        return str;
    };
    editor.valueChangedHandler = ^BOOL(NSString *_Nonnull newValue) {
        NSInteger value = newValue.integerValue * 1024;
        if (value != [MTHawkeyeUserDefaults shared].mallocReportThresholdInBytes)
            [MTHawkeyeUserDefaults shared].mallocReportThresholdInBytes = value;
        return YES;
    };
    return editor;
}

+ (MTHawkeyeSettingEditorCellEntity *)vmReportThresholdEditorCell {
    MTHawkeyeSettingEditorCellEntity *editor = [[MTHawkeyeSettingEditorCellEntity alloc] init];
    editor.title = @"VM Report Threshold";
    editor.inputTips = @"Only VM allocate records that accumulate greater than the threshold will be output to the report.";
    editor.editorKeyboardType = UIKeyboardTypeNumberPad;
    editor.valueUnits = @"KB";
    editor.setupValueHandler = ^NSString *_Nonnull {
        NSInteger threshold = [MTHawkeyeUserDefaults shared].vmAllocateReportThresholdInBytes / 1024;
        NSString *str = [NSString stringWithFormat:@"%@", @(threshold)];
        return str;
    };
    editor.valueChangedHandler = ^BOOL(NSString *_Nonnull newValue) {
        NSInteger value = newValue.integerValue;
        if (value != [MTHawkeyeUserDefaults shared].vmAllocateReportThresholdInBytes)
            [MTHawkeyeUserDefaults shared].vmAllocateReportThresholdInBytes = value;
        return YES;
    };
    return editor;
}

+ (MTHawkeyeSettingEditorCellEntity *)reportCategoryElementCountThresholdEditorCell {
    MTHawkeyeSettingEditorCellEntity *editor = [[MTHawkeyeSettingEditorCellEntity alloc] init];
    editor.title = @"Category Report Threshold";
    editor.inputTips = @"Only categories with a RecordCount greater than the threshold will be output to the report.";
    editor.editorKeyboardType = UIKeyboardTypeNumberPad;
    editor.setupValueHandler = ^NSString *_Nonnull {
        NSString *str = [NSString stringWithFormat:@"%@", @([MTHawkeyeUserDefaults shared].reportCategoryElementCountThreshold)];
        return str;
    };
    editor.valueChangedHandler = ^BOOL(NSString *_Nonnull newValue) {
        NSInteger value = newValue.integerValue;
        if (value != [MTHawkeyeUserDefaults shared].reportCategoryElementCountThreshold)
            [MTHawkeyeUserDefaults shared].reportCategoryElementCountThreshold = (uint32_t)value;
        return YES;
    };
    return editor;
}

+ (MTHawkeyeSettingSwitcherCellEntity *)singleChunkMallocSwitcherCell {
    MTHawkeyeSettingSwitcherCellEntity *entity = [[MTHawkeyeSettingSwitcherCellEntity alloc] init];
    entity.title = @"Trace Single Chunk Malloc";
    entity.setupValueHandler = ^BOOL {
        return [MTHawkeyeUserDefaults shared].chunkMallocTraceOn;
    };
    entity.valueChangedHandler = ^BOOL(BOOL newValue) {
        if (newValue != [MTHawkeyeUserDefaults shared].chunkMallocTraceOn) {
            [MTHawkeyeUserDefaults shared].chunkMallocTraceOn = newValue;
        }
        return YES;
    };
    return entity;
}

+ (MTHawkeyeSettingEditorCellEntity *)chunkMallocThresholdEditorCell {
    MTHawkeyeSettingEditorCellEntity *editor = [[MTHawkeyeSettingEditorCellEntity alloc] init];
    editor.title = @"Single Chunk Malloc Threshold";
    editor.editorKeyboardType = UIKeyboardTypeNumberPad;
    editor.valueUnits = @"KB";
    editor.setupValueHandler = ^NSString *_Nonnull {
        NSInteger threshold = [MTHawkeyeUserDefaults shared].chunkMallocThresholdInBytes / 1024;
        NSString *str = [NSString stringWithFormat:@"%@", @(threshold)];
        return str;
    };
    editor.valueChangedHandler = ^BOOL(NSString *_Nonnull newValue) {
        NSInteger value = newValue.integerValue * 1024;
        if (value != [MTHawkeyeUserDefaults shared].chunkMallocThresholdInBytes)
            [MTHawkeyeUserDefaults shared].chunkMallocThresholdInBytes = (uint32_t)value;
        return YES;
    };
    return editor;
}

@end

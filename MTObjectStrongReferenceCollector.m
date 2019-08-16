//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 8/16/19
// Created by: tripleCC
//


#import "MTObjectStrongReferenceCollector.h"

#import <MTHawkeye/MTHawkeyeDyldImagesUtils.h>
#import <objc/runtime.h>

@interface MTIvarInfo : NSObject
@property (copy, nonatomic, readonly) NSString *name;
@property (assign, nonatomic, readonly) ptrdiff_t offset;
@property (assign, nonatomic, readonly) NSInteger index;
@property (assign, nonatomic, readonly) Ivar ivar;
@property (assign, nonatomic, readonly) BOOL isObject;

- (instancetype)initWithIvar:(Ivar)ivar;
- (id)referenceFromObject:(id)object;
@end

@implementation MTIvarInfo
- (instancetype)initWithIvar:(Ivar)ivar {
    if (self = [super init]) {
        _ivar = ivar;
        _name = @(ivar_getName(ivar));
        _offset = ivar_getOffset(ivar);
        _index = _offset / sizeof(void *);
        const char *encoding = ivar_getTypeEncoding(ivar);
        _isObject = encoding[0] == '@';
    }
    return self;
}

- (id)referenceFromObject:(id)object {
    return object_getIvar(object, _ivar);
}
@end

@implementation MTObjectStrongReferenceCollector
@synthesize strongReferences = _strongReferences;

- (instancetype)initWithObject:(id)object {
    if (self = [super init]) {
        _object = object;
    }
    return self;
}

- (NSArray *)collectStrongObjectIvarsForClass:(Class)cls {
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(cls, &count);
    NSMutableArray <MTIvarInfo *> *infos = [NSMutableArray array];
    
    for (int i = 0; i < count; i++) {
        Ivar ivar = ivars[i];
        MTIvarInfo *ivarInfo = [[MTIvarInfo alloc] initWithIvar:ivar];
        [infos addObject:ivarInfo];
    }
    
    NSArray *objectIvars = [infos filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(MTIvarInfo *info, NSDictionary<NSString *,id> * _Nullable bindings) {
        return info.isObject;
    }]];
    const uint8_t *layout = class_getIvarLayout(cls);
    
    if (!layout) {
        return @[];
    }
    
    NSInteger ivarLocation = 1;
    if (infos.count > 0) {
        ivarLocation = infos.firstObject.index;
    }
    
    NSIndexSet *strongIvarIndexes = [self strongIvarIndexesForLayout:layout ivarLocation:ivarLocation];
    NSArray *strongObjectIvars = [objectIvars filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(MTIvarInfo *info, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [strongIvarIndexes containsIndex:info.index];
    }]];
    
    return strongObjectIvars;
}

- (NSIndexSet *)strongIvarIndexesForLayout:(const uint8_t *)layout ivarLocation:(NSInteger)ivarLocation {
    NSMutableIndexSet *indexes = [NSMutableIndexSet new];
    NSInteger strongIvarLocation = ivarLocation;

    while (*layout != '\x00') {
        int otherIvarLength = (*layout & 0xf0) >> 4;
        int strongIvarLength = (*layout & 0xf);
        
        strongIvarLocation += otherIvarLength;
        
        [indexes addIndexesInRange:NSMakeRange(strongIvarLocation, strongIvarLength)];
        strongIvarLocation += strongIvarLength;
        
        layout++;
    }
    
    return indexes;
}

- (NSArray <MTIvarInfo *> *)wrappedIvarList {
    Class curLevelClass = [_object class];
    NSMutableArray *ivarInfos = [NSMutableArray array];
    
    while (curLevelClass) {
        if (_stopForClsBlock && _stopForClsBlock(curLevelClass)) {
            break;
        }
        
        NSArray *infos = [self collectStrongObjectIvarsForClass:curLevelClass];
        [ivarInfos addObjectsFromArray:infos];
        curLevelClass = curLevelClass.superclass;
    }
    
    return ivarInfos;
}

- (NSArray *)strongReferences {
    if (!_strongReferences) {
        NSMutableArray *objects = [NSMutableArray array];
        NSArray *ivarInfos = [self wrappedIvarList];
        for (MTIvarInfo *info in ivarInfos) {
            id reference = [info referenceFromObject:_object];
            if (reference) {
                [objects addObject:reference];
            }
        }
        
        _strongReferences = objects;
    }
    
    return _strongReferences;
}
@end

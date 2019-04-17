//
//  ALeakingViewModel.h
//  MTHawkeyeDemo
//
//  Created by EuanC on 10/07/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ANormalProtocolWithNSObject;
@protocol ANormalProtocolWithoutNSObject;

@interface ALeakingViewModel : NSObject

@end


@interface AViewModelWithLeakingProperty : NSObject

@property (nonatomic, strong) ALeakingViewModel *viewModelWillLeak;

@end

@protocol ANormalProtocolWithoutNSObjectA;

@protocol ANormalProtocolWithoutNSObject

@property (nonatomic, strong, nullable) id<ANormalProtocolWithoutNSObjectA> aaaaaa;

@end

@protocol ANormalProtocolWithoutNSObjectA

@property (nonatomic, readonly) NSInteger index;

@end

@interface MBCCameraCapturingConfiguration : NSObject <ANormalProtocolWithoutNSObject>

@property (nonatomic, assign, readonly) BOOL fullScreenRatio;


/**
 实现 ANormalProtocolWithoutNSObject 的属性，如果未显示定义，不能直接通过 keyForValue 获取
 如果使用 KeyForValue 来遍历，需在 mt_memoryDebuggerIsPropertyNeedObserve 内判断 isValue 来过滤
 */
//@property (nonatomic, strong, nullable) id<ANormalProtocolWithoutNSObjectA> aaaaaa;

@end

NS_ASSUME_NONNULL_END

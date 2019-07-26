//
//  MTHBackgroundTaskStoreInfo.h
//  MTHawkeyeInjection
//
//  Created by Zed on 2019/5/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTHBackgroundTaskInfo : NSObject {
  @public
    uintptr_t titleFrame;
    uintptr_t *stackframes;
    size_t stackframesSize;
}
@property (assign, nonatomic) NSUInteger identifierID;
@property (copy, nonatomic) NSString *taskName;

- (void)setStackFrames:(uintptr_t *)stackframes stackframesSize:(size_t)size;

@end


@interface MTHBackgroundTaskStoreInfo : NSObject

@property (assign, nonatomic, readonly) NSUInteger recordedStartTaskCount;
@property (assign, nonatomic, readonly) NSUInteger recordedEndTasksCount;

@property (strong, nonatomic, readonly) NSDictionary *backgroundTasks;

- (void)syncAddBackgroundTask:(MTHBackgroundTaskInfo *)task;
- (void)syncEndBackgroundTaskWithIdentifierID:(NSUInteger)identifier;

@end

NS_ASSUME_NONNULL_END

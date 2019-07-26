//
//  MTHBackgroundTaskStoreInfo.m
//  MTHawkeyeInjection
//
//  Created by Zed on 2019/5/22.
//

#import "MTHBackgroundTaskStoreInfo.h"

@implementation MTHBackgroundTaskInfo

- (void)dealloc {
    if (self->stackframes) {
        free(self->stackframes);
        self->stackframes = nil;
    }
}

- (void)setStackFrames:(uintptr_t *)stackframes stackframesSize:(size_t)size {
    if (self->stackframes) {
        free(self->stackframes);
        self->stackframes = nil;
    }

    self->stackframes = (uintptr_t *)malloc(sizeof(uintptr_t) * size);
    memcpy(self->stackframes, stackframes, sizeof(uintptr_t) * size);
}

@end


@interface MTHBackgroundTaskStoreInfo ()

@property (strong, nonatomic) NSMutableDictionary *backgroundTasksM;

@property (assign, nonatomic) NSUInteger recordedStartTaskCount;
@property (assign, nonatomic) NSUInteger recordedEndTasksCount;

@end

@implementation MTHBackgroundTaskStoreInfo

- (instancetype)init {
    if (self = [super init]) {
        self.backgroundTasksM = [NSMutableDictionary new];

        self.recordedStartTaskCount = 0;
        self.recordedEndTasksCount = 0;
    }
    return self;
}

- (void)syncAddBackgroundTask:(MTHBackgroundTaskInfo *)task {
    @synchronized(self) {
        NSMutableString *dicKey = [NSMutableString new];
        // 以前 5 个堆栈的地址作为 Key 值
        const int kKeyFrameCount = 5;
        if (task->stackframesSize > kKeyFrameCount) {
            for (unsigned i = 0; i < kKeyFrameCount; i++) {
                [dicKey appendString:[NSString stringWithFormat:@"%lu", task->stackframes[i]]];
            }
        } else {
            for (unsigned i = 0; i < task->stackframesSize; i++) {
                [dicKey appendString:[NSString stringWithFormat:@"%lu", task->stackframes[i]]];
            }
        }

        NSMutableDictionary *tmp = [self.backgroundTasksM objectForKey:dicKey];
        if (tmp) {
            NSUInteger startedCount = [[tmp objectForKey:@"startedCount"] unsignedIntegerValue];
            [tmp setObject:@(++startedCount) forKey:@"startedCount"];

            NSMutableArray *arrayM = [[tmp objectForKey:@"taskIDs"] mutableCopy];
            [arrayM addObject:@(task.identifierID)];
            [tmp setObject:arrayM forKey:@"taskIDs"];

        } else {
            // create new backgroundTask
            NSMutableDictionary *dic = [NSMutableDictionary new];
            [dic setObject:task.taskName forKey:@"taskName"];
            [dic setObject:@(1) forKey:@"startedCount"];
            [dic setObject:@(0) forKey:@"endedCount"];
            [dic setObject:@[ @(task.identifierID) ] forKey:@"taskIDs"];
            [dic setObject:[NSString stringWithFormat:@"%p", (void *)task->titleFrame] forKey:@"titleFrame"];

            NSMutableString *stackInStr = [[NSMutableString alloc] init];
            for (int i = 0; i < task->stackframesSize; ++i) {
                [stackInStr appendFormat:@"%p,", (void *)task->stackframes[i]];
            }
            if (stackInStr.length > 1) {
                [stackInStr deleteCharactersInRange:NSMakeRange(stackInStr.length - 1, 1)];
            }
            [dic setObject:stackInStr forKey:@"stackFrames"];

            [self.backgroundTasksM setObject:dic forKey:dicKey];
        }
        self.recordedStartTaskCount++;
    }
}

- (void)syncEndBackgroundTaskWithIdentifierID:(NSUInteger)identifier {
    @synchronized(self) {
        // 先根据 identifier 查找对应的字典修改 endedCount的值
        [self.backgroundTasksM enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull obj, BOOL *_Nonnull stop) {
            NSArray *arrI = [obj objectForKey:@"taskIDs"];
            if ([arrI containsObject:@(identifier)]) {
                NSMutableArray *arrM = [arrI mutableCopy];
                [arrM removeObject:@(identifier)];
                [obj setObject:[arrM copy] forKey:@"taskIDs"];

                NSUInteger endedCount = [[obj objectForKey:@"endedCount"] unsignedIntegerValue];
                [obj setObject:@(++endedCount) forKey:@"endedCount"];
                *stop = YES;

                self.recordedEndTasksCount++;
            }
        }];
    }
}

- (NSDictionary *)backgroundTasks {
    @synchronized(self) {
        return [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:self.backgroundTasksM]];
    }
}

@end

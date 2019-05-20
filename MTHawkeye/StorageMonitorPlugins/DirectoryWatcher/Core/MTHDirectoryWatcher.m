//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/11/6
// Created by: Huni
//


#import "MTHDirectoryWatcher.h"

#include <dirent.h>
#include <fcntl.h>
#include <sys/event.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

#import <CoreFoundation/CoreFoundation.h>

@interface MTHDirectoryWatcher (MTHDirectoryWatcherPrivate)
- (BOOL)startMonitoringDirectory:(NSString *)dirPath;
- (void)kqueueFired;
@end


#pragma mark -

@interface MTHDirectoryWatcher () {
    int dirFD;
    int kq;

    CFFileDescriptorRef dirKQRef;
}

@property (nonatomic, copy) NSString *watchPath;
@property (nonatomic, copy) NSString *dirPath;
@property (nonatomic, weak) id<MTHDirectoryWatcherDelegate> delegate;
@property (nonatomic, assign) CGFloat folderSize;
@property (nonatomic, assign) NSTimeInterval taskTime;
@end

@implementation MTHDirectoryWatcher

- (instancetype)init {
    (self = [super init]);

    dirFD = -1;
    kq = -1;
    dirKQRef = NULL;

    return self;
}

- (void)dealloc {
    [self invalidate];
}

+ (MTHDirectoryWatcher *)directoryWatcherWithPath:(NSString *)watchPath
                             changeReportInterval:(NSTimeInterval)changeReportInterval
                                         delegate:(id)watchDelegate {
    MTHDirectoryWatcher *retVal = NULL;
    if ((watchDelegate != NULL) && (watchPath != NULL)) {
        MTHDirectoryWatcher *tempManager = [[MTHDirectoryWatcher alloc] init];
        tempManager.delegate = watchDelegate;
        tempManager.changeReportInterval = changeReportInterval;
        tempManager.watchPath = watchPath;
        if ([tempManager startMonitoringDirectory:watchPath]) {
            // Everything appears to be in order, so return the MTHDirectoryWatcher.
            // Otherwise we'll fall through and return NULL.
            retVal = tempManager;
        }
    }
    return retVal;
}

- (void)invalidate {
    if (dirKQRef != NULL) {
        CFFileDescriptorInvalidate(dirKQRef);
        CFRelease(dirKQRef);
        dirKQRef = NULL;
        // We don't need to close the kq, CFFileDescriptorInvalidate closed it instead.
        // Change the value so no one thinks it's still live.
        kq = -1;
    }

    if (dirFD != -1) {
        close(dirFD);
        dirFD = -1;
    }
}

+ (unsigned long long)fileSizeAtPath:(NSString *)path {
    return [self fileSizeAtPathWithC:[path cStringUsingEncoding:NSUTF8StringEncoding]];
}

+ (unsigned long long)fileSizeAtPathWithC:(const char *)folderPath {
    long long folderSize = 0;
    DIR *dir = opendir(folderPath);
    if (dir == NULL) return 0;
    struct dirent *child;
    while ((child = readdir(dir)) != NULL) {
        if (child->d_type == DT_DIR && ((child->d_name[0] == '.' && child->d_name[1] == 0) || (child->d_name[0] == '.' && child->d_name[1] == '.' && child->d_name[2] == 0))) continue;

        size_t folderPathLength = strlen(folderPath);
        char childPath[1024];
        stpcpy(childPath, folderPath);
        if (folderPath[folderPathLength - 1] != '/') {
            childPath[folderPathLength] = '/';
            folderPathLength++;
        }
        stpcpy(childPath + folderPathLength, child->d_name);
        childPath[folderPathLength + child->d_namlen] = 0;
        if (child->d_type == DT_DIR) {
            folderSize += [[self class] fileSizeAtPathWithC:childPath];
            // Add the space occupied by the directory itself
            struct stat st;
            if (lstat(childPath, &st) == 0)
                folderSize += st.st_size;
        } else if (child->d_type == DT_REG || child->d_type == DT_LNK) {
            struct stat st;
            if (lstat(childPath, &st) == 0)
                folderSize += st.st_size;
        }
    }
    closedir(dir);
    return folderSize;
}
@end

#pragma mark - Private

@implementation MTHDirectoryWatcher (MTHDirectoryWatcherPrivate)

- (void)kqueueFired {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        struct kevent event;
        struct timespec timeout = {0, 0};
        int eventCount;

        eventCount = kevent(strongSelf->kq, NULL, 0, &event, 1, &timeout);

        // call our delegate of the directory change
        NSTimeInterval eclipse = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] - strongSelf.taskTime;
        if (fabs(strongSelf.taskTime) < DBL_EPSILON || eclipse > strongSelf.changeReportInterval) {
            strongSelf.reportCount++;
            strongSelf.taskTime = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970];
            strongSelf.folderSize = [[strongSelf class] fileSizeAtPath:strongSelf.dirPath] ?: 0;

            dispatch_async(dispatch_get_main_queue(), ^(void) {
                if (strongSelf.delegate && [strongSelf.delegate respondsToSelector:@selector(directoryDidChange:)]) {
                    [strongSelf.delegate directoryDidChange:strongSelf];
                }
            });
        }

        if (strongSelf->dirKQRef != NULL) {
            CFFileDescriptorEnableCallBacks(strongSelf->dirKQRef, kCFFileDescriptorReadCallBack);
        }
    });
}

static void KQCallback(CFFileDescriptorRef kqRef, CFOptionFlags callBackTypes, void *info) {
    MTHDirectoryWatcher *obj;

    obj = (__bridge MTHDirectoryWatcher *)info;

    NSCAssert(callBackTypes == kCFFileDescriptorReadCallBack, @"callback 类型请保持一致");
    NSCAssert(kqRef == obj->dirKQRef, @"文件描述符保持一致");

    [obj kqueueFired];
}

- (BOOL)startMonitoringDirectory:(NSString *)dirPath {
    // Double initializing is not going to work...
    if ((dirKQRef == NULL) && (dirFD == -1) && (kq == -1)) {
        // Open the directory we're going to watch
        dirFD = open([dirPath fileSystemRepresentation], O_EVTONLY);

        if (dirFD >= 0) {
            // Create a kqueue for our event messages...
            kq = kqueue();
            if (kq >= 0) {
                struct kevent eventToAdd;
                eventToAdd.ident = dirFD;
                eventToAdd.filter = EVFILT_VNODE;
                eventToAdd.flags = (EV_ADD | EV_CLEAR);
                eventToAdd.fflags = (NOTE_WRITE | NOTE_EXTEND | NOTE_DELETE);
                eventToAdd.data = 0;
                eventToAdd.udata = NULL;

                int errNum = kevent(kq, &eventToAdd, 1, NULL, 0, NULL);

                if (errNum == 0) {
                    CFFileDescriptorContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
                    CFRunLoopSourceRef rls;

                    // Passing true in the third argument so CFFileDescriptorInvalidate will close kq.
                    self.dirPath = dirPath;
                    dirKQRef = CFFileDescriptorCreate(NULL, kq, true, KQCallback, &context);
                    if (dirKQRef != NULL) {
                        rls = CFFileDescriptorCreateRunLoopSource(NULL, dirKQRef, 0);
                        if (rls != NULL) {
                            CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
                            CFRelease(rls);
                            CFFileDescriptorEnableCallBacks(dirKQRef, kCFFileDescriptorReadCallBack);

                            // If everything worked, return early and bypass shutting things down
                            return YES;
                        }
                        // Couldn't create a runloop source, invalidate and release the CFFileDescriptorRef
                        CFFileDescriptorInvalidate(dirKQRef);
                        CFRelease(dirKQRef);
                        dirKQRef = NULL;
                    }
                }
                // kq is active, but something failed, close the handle...
                close(kq);
                kq = -1;
            }
            // file handle is open, but something failed, close the handle...
            close(dirFD);
            dirFD = -1;
        }
    }
    return NO;
}

@end

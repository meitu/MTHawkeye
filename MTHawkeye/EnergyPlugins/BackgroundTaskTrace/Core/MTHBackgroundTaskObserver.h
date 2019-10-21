//
//  MTHBackgroundTaskObserve.h
//  MTHawkeyeInjection
//
//  Created by Zed on 2019/5/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MTHBackgroundTaskObserverProcessDelegate <NSObject>

- (void)processBeginBackgroundTask:(NSUInteger)identifierID taskName:(NSString *)name;
- (void)processEndBackgroundTask:(NSUInteger)identifierID;

@end


@interface MTHBackgroundTaskObserver : NSObject

+ (void)setMTHBackgroundTaskObserverProcessDelegate:(_Nullable id<MTHBackgroundTaskObserverProcessDelegate>)delegate;
+ (void)setEnabled:(BOOL)enabled;
+ (BOOL)isEnabled;

@end

NS_ASSUME_NONNULL_END

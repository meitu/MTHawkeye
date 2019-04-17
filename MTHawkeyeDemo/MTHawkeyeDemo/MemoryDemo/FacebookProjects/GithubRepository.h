//
//  GithubRepository.h
//  MTHawkeyeDemo
//
//  Created by cqh on 29/06/2017.
//  Copyright © 2017 meitu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GithubRepository : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *shortDescription;
@property (nonatomic, copy) NSURL *url;

- (instancetype)initWithName:(NSString *)name shortDescription:(NSString *)shortDescription url:(NSURL *)url;

@end

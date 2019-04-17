//
//  GithubRepository.m
//  MTHawkeyeDemo
//
//  Created by cqh on 29/06/2017.
//  Copyright © 2017 meitu. All rights reserved.
//

#import "GithubRepository.h"

@implementation GithubRepository

- (instancetype)initWithName:(NSString *)name shortDescription:(NSString *)shortDescription url:(NSURL *)url {
    if (self = [super init]) {
        _name = [name copy];
        _shortDescription = ([shortDescription class] != [NSNull class]) ? [shortDescription copy] : @"No Description";
        _url = [url copy];
    }
    return self;
}

@end

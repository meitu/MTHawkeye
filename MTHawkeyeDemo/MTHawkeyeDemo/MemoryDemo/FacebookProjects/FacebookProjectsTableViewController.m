//
//  FirstTableViewController.m
//  MTHawkeyeDemo
//
//  Created by cqh on 29/06/2017.
//  Copyright © 2017 meitu. All rights reserved.
//

#import "FacebookProjectsTableViewController.h"
#import "FacebookProjectViewController.h"
#import "GithubRepository.h"

#ifdef DEBUG

#endif


static NSString *const kFacebookOpenSourceReusableIdentifier = @"kFacebookOpenSourceReusableIdentifier";

@interface FacebookProjectsTableViewController ()

@end

@implementation FacebookProjectsTableViewController {
    NSArray<GithubRepository *> *_data;
    NSInteger _logID;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _data = @[];
    self.title = @"Facebook Open Source";

    NSString *path = [[NSBundle mainBundle] pathForResource:@"FacebookRepos" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:path];

    NSArray *json = [NSJSONSerialization JSONObjectWithData:data
                                                    options:NSJSONReadingAllowFragments
                                                      error:nil];
    if (json) {
        [self _parseData:json];
        [self.tableView reloadData];
    }
}

- (void)_parseData:(NSArray *)data {
    NSMutableArray<GithubRepository *> *parsedData = [NSMutableArray array];
    for (NSDictionary *repository in data) {
        GithubRepository *githubRepository =
            [[GithubRepository alloc] initWithName:repository[@"name"]
                                  shortDescription:repository[@"description"]
                                               url:[NSURL URLWithString:repository[@"html_url"]]];
        [parsedData addObject:githubRepository];
    }

    _data = [parsedData copy];
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _data.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kFacebookOpenSourceReusableIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:kFacebookOpenSourceReusableIdentifier];
    }

    cell.textLabel.text = _data[indexPath.row].name;
    cell.detailTextLabel.text = _data[indexPath.row].shortDescription;
    cell.detailTextLabel.numberOfLines = 0;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 100;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    FacebookProjectViewController *projectViewController =
        [[FacebookProjectViewController alloc] initWithName:_data[indexPath.row].name
                                                        URL:_data[indexPath.row].url];
    [self.navigationController pushViewController:projectViewController
                                         animated:YES];
}

@end

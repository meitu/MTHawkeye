//
//  MTURLConnectionInjectTestViewController.m
//  MTHawkeyeDemo
//
//  Created by EuanC on 28/08/2017.
//  Copyright © 2017 Meitu. All rights reserved.
//

#import "MTURLConnectionInjectTestViewController.h"

@interface MTURLConnectionInjectTestViewController () <NSURLConnectionDelegate, NSURLConnectionDataDelegate, NSURLSessionDelegate>

@property (nonatomic, copy) NSArray<NSString *> *itemTitles;

@property (nonatomic, strong) NSURLRequest *request;

@end

@implementation MTURLConnectionInjectTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.itemTitles = @[
        @"URLConnection Without delegate",
        @"URLSession Without delegate",
        @"Bad URL Request",
    ];

    self.request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.baidu.com"]];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.itemTitles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"network-inject-test" forIndexPath:indexPath];
    cell.textLabel.text = self.itemTitles[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.row == 0) {
        [self urlConnectionWithoutDelegate];
    } else if (indexPath.row == 1) {
        [self urlSessionWithouDelegate];
    } else if (indexPath.row == 2) {
        [self badURLRequestDemo];
    }
}

// MARK: - Tests
- (void)urlConnectionWithoutDelegate {
    NSURLConnection *conn = [NSURLConnection connectionWithRequest:self.request delegate:self];
    [conn start];
}

- (void)urlSessionWithouDelegate {
    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:nil];
    NSURLSessionTask *task = [session dataTaskWithRequest:self.request];
    [task resume];
}

- (void)badURLRequestDemo {
    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:nil];
    NSURL *url = [NSURL URLWithString:@" http://www.host.com"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSessionTask *task = [session dataTaskWithRequest:request];
    [task resume];
}

// MARK: - Without Connection/Session Delegates
//- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
//    NSLog(@"%@ did finish loading", connection);
//}

@end

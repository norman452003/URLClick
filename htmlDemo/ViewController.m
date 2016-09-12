//
//  ViewController.m
//  htmlDemo
//
//  Created by gongxin on 16/9/12.
//  Copyright © 2016年 gongxin. All rights reserved.
//

#import "ViewController.h"
#import "AHHTMLView.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *s = @"百度 http://www.baidu.com  谷歌:http://www.google.com";
    AHHTMLView *htmlView = [[AHHTMLView alloc] initWithString:s font:[UIFont systemFontOfSize:14] textColor:[UIColor grayColor] maxWidth:200 clickBlock:^(NSString *value) {
        NSLog(@"%@",value);
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"" message:value delegate:nil cancelButtonTitle:@"确定" otherButtonTitles: nil];
        [alertView show];
    }];
    [self.view addSubview:htmlView];
    htmlView.center = CGPointMake(self.view.center.x - 100, self.view.center.y);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

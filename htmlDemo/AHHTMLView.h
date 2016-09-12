//
//  AHHTMLView.h
//  htmlDemo
//
//  Created by gongxin on 16/9/12.
//  Copyright © 2016年 gongxin. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AHHTMLView : UIImageView

- (instancetype)initWithString:(NSString *)str font:(UIFont *)font textColor:(UIColor *)textColor maxWidth:(CGFloat)maxWidth clickBlock:(void(^)(NSString *value))clickBlock;

@end

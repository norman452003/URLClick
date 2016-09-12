//
//  AHHTMLView.m
//  htmlDemo
//
//  Created by gongxin on 16/9/12.
//  Copyright © 2016年 gongxin. All rights reserved.
//

#import "AHHTMLView.h"
#import <CoreText/CoreText.h>

static NSString *const URLRegular = @"(http|ftp|https):\\/\\/[\\w\\-_]+(\\.[\\w\\-_]+)+([\\w\\-\\.,@?^=%&amp;:/~\\+#]*[\\w\\-\\@?^=%&amp;/~\\+#])?";
static NSString *const kTextShouldRespondTapKey = @"kTextShouldRespondTapKey";

static inline NSRegularExpression* URLRegularExpression() {
    static NSRegularExpression* _URLRegularExpression = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _URLRegularExpression = [[NSRegularExpression alloc] initWithPattern:URLRegular options:NSRegularExpressionAnchorsMatchLines error:nil];
    });
    return _URLRegularExpression;
}

@interface AHHTMLView ()

@property (nonatomic, copy) void(^clickBlock)(NSString *url);
@property (nonatomic, copy) NSString *str;
@property (nonatomic) CGFloat maxWidth;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic) CTFrameRef frameRef;

@end

@implementation AHHTMLView

- (instancetype)initWithString:(NSString *)str font:(UIFont *)font textColor:(UIColor *)textColor maxWidth:(CGFloat)maxWidth clickBlock:(void (^)(NSString *))clickBlock{
    self = [super init];
    if (self) {
        _str = str;
        _font = font;
        _textColor = textColor;
        _maxWidth = maxWidth;
        _clickBlock = clickBlock;
        [self generateImage];
    }
    return self;
}

- (void)generateImage{
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
    
        NSAttributedString *attributeStr = [[NSAttributedString alloc] initWithString:_str attributes:@{NSForegroundColorAttributeName : _textColor,NSFontAttributeName : _font}];
        attributeStr = [self parseHttpURLWithAttributeString:attributeStr];
        
        CTFramesetterRef setterRef = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attributeStr);
        CGSize size = CTFramesetterSuggestFrameSizeWithConstraints(setterRef, (CFRangeMake(0, 0)), nil, CGSizeMake(_maxWidth, CGFLOAT_MAX), NULL);
        
        UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, size.width, size.height)];
        CTFrameRef ref = CTFramesetterCreateFrame(setterRef, CFRangeMake(0, 0), path.CGPath, NULL);
        self.frameRef = ref;
        
        UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
        CGContextRef contextRef = UIGraphicsGetCurrentContext();
        CGContextTranslateCTM(contextRef, 0, size.height);
        CGContextScaleCTM(contextRef, 1.0, -1.0);
        CTFrameDraw(ref, contextRef);
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        CFRelease(setterRef);
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.image = image;
            [self sizeToFit];
            [self generateTapGesture];
        });
    });
}

- (NSAttributedString *)parseHttpURLWithAttributeString:(NSAttributedString *)attributeStr{
    
    NSMutableAttributedString *mAttribute = [[NSMutableAttributedString alloc] initWithAttributedString:attributeStr];
    NSString *text = mAttribute.string;
    NSArray *resultArray = [URLRegularExpression() matchesInString:text options:0 range:NSMakeRange(0, text.length)];
    
    for (NSTextCheckingResult *match in resultArray) {
        NSRange range = match.range;
        NSString *content = [text substringWithRange:range];
        NSAttributedString *changeAttribute = [[NSAttributedString alloc] initWithString:content attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:14],NSForegroundColorAttributeName : [UIColor blueColor]}];
        [mAttribute replaceCharactersInRange:range withAttributedString:changeAttribute];
        [mAttribute addAttribute:kTextShouldRespondTapKey value:content range:range];
    }
    return mAttribute.copy;
}

- (void)generateTapGesture{
    self.userInteractionEnabled = YES;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
    [self addGestureRecognizer:tap];
}

- (void)tap:(UITapGestureRecognizer *)tap{
    CGPoint point = [tap locationInView:self];
    //返回每一行
    CFArrayRef lines = CTFrameGetLines(self.frameRef);
    CGPoint origins[CFArrayGetCount(lines)];
    //获取每行原点坐标
    CTFrameGetLineOrigins(self.frameRef, CFRangeMake(0, 0), origins);
    
    CGPathRef path = CTFrameGetPath(self.frameRef);
    CGRect boundRect = CGPathGetBoundingBox(path);
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformMakeTranslation(0, boundRect.size.height);
    transform = CGAffineTransformScale(transform, 1.f, -1.f);
    for (int i = 0; i < CFArrayGetCount(lines); i++) {
        CGPoint linePoint = origins[i];
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        CGRect flippedRect = [self _getLineBounds:line point:linePoint];
        CGRect rect = CGRectApplyAffineTransform(flippedRect, transform);
        CGRect adjustRect = CGRectMake(rect.origin.x + boundRect.origin.x,
                                       rect.origin.y + boundRect.origin.y,
                                       rect.size.width,
                                       rect.size.height);
        if (CGRectContainsPoint(adjustRect, point)) {
            // 将点击的坐标转换成相对于当前行的坐标
            CGPoint relativePoint = CGPointMake(point.x - CGRectGetMinX(adjustRect),
                                                point.y - CGRectGetMinY(adjustRect));
            // 获得当前点击坐标对应的字符串偏移
            CFIndex index = CTLineGetStringIndexForPosition(line, relativePoint);
            //获取点击的Run
            CTRunRef touchedRun;
            NSArray* runObjArray = (NSArray *)CTLineGetGlyphRuns(line);
            for (NSUInteger i = 0 ; i < runObjArray.count; i++) {
                CTRunRef runObj = (__bridge CTRunRef)[runObjArray objectAtIndex:i];
                CFRange range = CTRunGetStringRange((CTRunRef)runObj);
                if (NSLocationInRange(index, NSMakeRange(range.location, range.length))) {
                    touchedRun = runObj;
                    NSDictionary* runAttribues = (NSDictionary *)CTRunGetAttributes(touchedRun);
                    if ([runAttribues objectForKey:kTextShouldRespondTapKey]) {
                        id content = runAttribues[kTextShouldRespondTapKey];
                        if (self.clickBlock) {
                            self.clickBlock(content);
                        }
                    }
                    
                }
            }
        }
    }
}

- (CGRect)_getLineBounds:(CTLineRef)line point:(CGPoint)point {
    CGFloat ascent = 0.0f;
    CGFloat descent = 0.0f;
    CGFloat leading = 0.0f;
    CGFloat width = (CGFloat)CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
    CGFloat height = ascent + descent;
    return CGRectMake(point.x, point.y - descent, width, height);
}

- (void)dealloc{
    CFRelease(self.frameRef);
}

@end

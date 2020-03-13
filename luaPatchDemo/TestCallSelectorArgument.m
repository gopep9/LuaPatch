//
//  TestLuaToOCValue.m
//  luaPatchDemo
//
//  Created by 黄钊 on 2019/9/7.
//  Copyright © 2019 hz. All rights reserved.
//

#import "TestCallSelectorArgument.h"
#import <UIKit/UIKit.h>
#include "string.h"
//测试lua传递参数给oc

static BOOL doubleEqual(double a,double b){
    double x = a - b;
    const double EPSINON = 0.000001;
    return (x >= -EPSINON)&&(x <= EPSINON);
}

@implementation TestCallSelectorArgument

+(void)checkInt:(int)i{
    NSAssert(i == 1,@"TestLuaToOCValue checkInt value error");
}

+(void)checkDouble:(double)d{
    NSAssert(doubleEqual(d,1.1),@"TestLuaToOCValue checkDouble value error");
}

+(void)checkNSString:(NSString *)str{
    NSAssert([str isEqualToString:@"hello world"],@"TestLuaToOCValue checkNSString value error");
}

+(void)checkNSNumber:(NSNumber *)num{
    NSAssert(num.intValue == 1,@"TestLuaToOCValue checkNSNumber value error");
}

+(void)checkOCStructWithRect:(CGRect)rect Point:(CGPoint)point Size:(CGSize)size Range:(NSRange)range{
    NSAssert(rect.origin.x == 1 && rect.origin.y == 2 && rect.size.width == 3 && rect.size.height == 4, @"TestLuaToOCValue checkOCStruct rect error");
    NSAssert(point.x == 1 && point.y == 2,@"TestLuaToOCValue checkOCStruct point error");
    NSAssert(size.width == 1 && size.height == 2,@"TestLuaToOCValue checkOCStruct size error");
    NSAssert(range.location == 1 && range.length == 2,@"TestLuaToOCValue checkOCStruct range error");
}

+(void)checkIsDictionary:(id)i{
    NSAssert([i isKindOfClass:NSDictionary.class],@"TestLuaToOCValue checkIsDictionary error");
}

+(void)checkIsDictionaryClass:(id)i{
    NSAssert(i == NSDictionary.class,@"TestLuaToOCValue checkIsDictionaryClass error");
}

+(void)checkCStr:(char *)str{
    NSAssert(strcmp(str, "hello world") == 0,@"TestLuaToOCValue checkCStr error");
}

+(void)checkSEL:(SEL)sel{
    NSAssert([NSStringFromSelector(sel) isEqualToString:@"checkSEL"],@"TestLuaToOCValue checkSEL error");
}

+(void)checkBlock:(int (^)(int))block{
    int ret = block(1);
    NSAssert(ret == 2, @"TestLuaToOCValue checkBlock error");
}

+(void)checkBlock2:(void (^)(NSString*))block{
    block(@"hello");
}

@end

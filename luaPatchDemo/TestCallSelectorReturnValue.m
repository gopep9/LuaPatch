//
//  TestReturnValue.m
//  luaPatchDemo
//
//  Created by 黄钊 on 2019/9/3.
//  Copyright © 2019 hz. All rights reserved.
//

#import "TestCallSelectorReturnValue.h"
#import <UIKit/UIKit.h>


@implementation TestCallSelectorReturnValue


+(void)returnVoid{
    NSLog(@"call returnVoid");
}
    
+(CGRect)returnCGRect{
    return CGRectMake(1, 2, 3, 4);
}
    
+(CGPoint)returnCGPoint{
    return CGPointMake(1, 2);
}
    
+(CGSize)returnCGSize{
    return CGSizeMake(1, 2);
}

+(NSRange)returnNSRange{
    return NSMakeRange(1, 2);
}

+(int)returnInt{
    return 1;
}

+(double)returnDouble{
    return 1.1;
}

+(NSString *)returnStr{
    return [NSString stringWithFormat:@"hello world"];
}

+(NSNumber *)returnNum{
    return @1;
}

+(char *)returnCStr{
    return "hello world";
}

+(id)returnDict{
    return [NSDictionary new];
}

+(Class)returnCls{
    return NSDictionary.class;
}

+(SEL)returnSEL{
    return @selector(returnCls);
}

+(int (^)(int))returnBlock{
    return ^int (int a){
        return a+1;
    };
}

+(void (^)(NSString*))returnStrParamBlock{
    id block = ^void(NSString *a){
        NSLog(@"call block in returnStrParamBlock with param %@",a);
    };
    return block;
}

+(void)checkBlock:(int (^)(int))block{
    int ret = block(1);
    NSAssert(ret == 2, @"TestCallSelectorReturnValue checkBlock error");
}
@end

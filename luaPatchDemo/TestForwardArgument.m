//
//  TestForwardArgument.m
//  luaPatchDemo
//
//  Created by 黄钊 on 2019/9/7.
//  Copyright © 2019 hz. All rights reserved.
//

#import "TestForwardArgument.h"

@implementation TestForwardArgument

+(int)checkInt:(int)i{
    return 0;
}

+(double)checkDouble:(double)d{
    return 0;
}

+(id)checkId:(id)i{
    return nil;
}

+(SEL)checkSEL:(SEL)sel{
    return @selector(a:);
}

+(void*)checkPoint:(void *)p{
    return NULL;
}

+(Class)checkClass:(Class)cls{
    return nil;
}

+(NSNumber*)checkNum:(NSNumber*)num{
    return @0;
}

+(NSString*)checkStr:(NSString*)str{
    return nil;
}

+(void)startCheckArgument{
    //测试返回值
    NSAssert([self.class checkInt:1] == 1,@"TestForwardArgument checkInt error");
    NSAssert([self.class checkDouble:1.1] == 1.1,@"TestForwardArgument checkDouble error");
    NSAssert([[self.class checkId:[NSDictionary new]] isKindOfClass:NSDictionary.class],@"TestForwardArgument checkId error");
    NSAssert([NSStringFromSelector([self.class checkSEL:@selector(checkSEL:)]) isEqualToString:@"checkSEL:"],@"TestForwardArgument checkSEL error");
    NSAssert(strcmp([self.class checkPoint:"hello world"], "hello world") == 0,@"TestForwardArgument checkPoint error");
    NSAssert([self.class checkClass:NSDictionary.class] == NSDictionary.class,@"TestForwardArgument checkClass error");
    NSAssert([[self.class checkNum:@1] isEqualToNumber:@1], @"TestForwardArgument checkNum error");
    NSAssert([[self.class checkStr:@"hello world"] isEqualToString:@"hello world"],@"TestForwardArgument checkStr error");    
}

@end

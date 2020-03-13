//
//  TestVariableParameter.m
//  luaPatchDemo
//
//  Created by 黄钊 on 2019/9/15.
//  Copyright © 2019 hz. All rights reserved.
//

#import "TestVariableParameter.h"

@implementation TestVariableParameter

//+(NSString *)inputVariableParameter:(id)arg1,...{
//    NSLog(@"call inputVariableParameter");
//    va_list args;
//    va_start(args,arg1);
//    NSString *str = [NSString new];
//    if(arg1){
//        id other;
//        NSLog(@"%@",arg1);
//        str = [str stringByAppendingString:arg1];
////        while((other = va_arg(args,id)) != nil){
////            NSLog(@"%@",other);
////            str = [str stringByAppendingString:other];
////        }
//    }
//    va_end(args);
//    return str;
//}

+ (NSString *)logWithFormat:(NSString *)format, ... {
    va_list paramList;
    va_start(paramList,format);
    NSString* log = [[NSString alloc]initWithFormat:format arguments:paramList];
//    NSString* logToStore = [log stringByAppendingString:@"\n"];
    va_end(paramList);
    return log;
}

@end

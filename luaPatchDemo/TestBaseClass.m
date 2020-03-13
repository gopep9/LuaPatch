//
//  TestBaseClass.m
//  luaPatchDemo
//
//  Created by 黄钊 on 2019/9/9.
//  Copyright © 2019 hz. All rights reserved.
//

#import "TestBaseClass.h"

@implementation TestBaseClass

-(int)funcInstance1{
    return 1;
}

-(int)funcInstance3{
    return 1;
}


-(int)funcInstance5{
    @throw [NSException exceptionWithName:@"call error function" reason:@"call funcInstance5" userInfo:nil];
    return 0;
}
@end

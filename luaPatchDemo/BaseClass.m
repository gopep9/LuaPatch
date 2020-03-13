//
//  BaseClass.m
//  luaPatchDemo
//
//  Created by 黄钊 on 2019/8/26.
//  Copyright © 2019 hz. All rights reserved.
//

#import "BaseClass.h"

@implementation BaseClass

-(int)funcInstance{
    return 1;
}

+(int)funcClass{
    return 2;
}

-(int)funcInstance2{
    NSLog(@"call BaseClass funcInstance2 in oc");
    return 1;
}

@end

@implementation CenterClass

@end

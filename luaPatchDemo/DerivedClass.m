//
//  DerivedClass.m
//  luaPatchDemo
//
//  Created by 黄钊 on 2019/8/26.
//  Copyright © 2019 hz. All rights reserved.
//

#import "DerivedClass.h"

@implementation DerivedClass

-(int)funcInstance{
    return 3;
}

+(int)funcClass{
    return 4;
}

-(int)funcInstance2{
    NSLog(@"call DerivedClass funcInstance2 in oc");
    return 6;
}
@end

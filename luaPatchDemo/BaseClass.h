//
//  BaseClass.h
//  luaPatchDemo
//
//  Created by 黄钊 on 2019/8/26.
//  Copyright © 2019 hz. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BaseClass : NSObject

-(int)funcInstance;

+(int)funcClass;

@end

@interface CenterClass : BaseClass

@end

NS_ASSUME_NONNULL_END

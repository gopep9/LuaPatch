//
//  ViewController.h
//  luaPatch
//
//  Created by 黄钊 on 2019/3/28.
//  Copyright © 2019 hz. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "lauxlib.h"
#import "lualib.h"


@interface ViewController : UIViewController

+(lua_State *)getLuaState;

@end


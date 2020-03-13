//
//  LPEngineSpec.m
//  luaPatchDemo
//
//  Created by 黄钊 on 2019/8/22.
//  Copyright 2019 hz. All rights reserved.
//

#import <Kiwi/Kiwi.h>
#import "LPEngine.h"
#import "lauxlib.h"
#import "lualib.h"
#import "ViewController.h"


// 目标，测试以下函数在各种情况下的是否正常
//lua_register(L, "callC", callC);
//lua_register(L, "callI", callI);
//lua_register(L, "callSuperI", callSuperI);
//
//lua_register(L, "makeOCStruct", makeOCStruct);
//lua_register(L, "getNullObject", getNullObject);
//lua_register(L, "getNilObject", getNilObject);
//
//lua_register(L, "redefineClassMethod", redefineClassMethod);
//lua_register(L, "redefineInstanceMethod", redefineInstanceMethod);
//lua_register(L, "addClassMethod", addClassMethod);
//lua_register(L, "addInstanceMethod", addInstanceMethod);
//
//lua_register(L, "retainObject", retainObject);
//lua_register(L, "releaseObject", releaseObject);
//
//lua_register(L, "dispatchAfter", dispatchAfter);
//lua_register(L, "dispatchAsyncMain", dispatchAsyncMain);
//lua_register(L, "dispatchSyncMain", dispatchSyncMain);
// 好难。。。 我觉得能把上面最上面的几个测试就不容易了，要考虑传入的参数，返回的参数等各种情况
// 字符串编码要不要考虑
// 是否每个单元测试都要lua发起，返回的对象是否也要想办法测试是否能够被调用函数
//wiki:
//https://github.com/kiwi-bdd/Kiwi/wiki


SPEC_BEGIN(LPEngineSpec)

describe(@"LPEngine", ^{
    beforeAll(^{
    });
    context(@"test call callI with stringByAppendingString:", ^{
        NSString *str = [NSString stringWithUTF8String:"a"];
        it(@"call stringByAppendingString: normal", ^{
            NSArray *arguments = @[@"b"];
            id ret = callSelector(nil, @"stringByAppendingString:", arguments, str, NO);
            NSLog(@"ret classname is %@",[ret class]);
            [[ret should] beKindOfClass:NSString.class];
            [[ret should] equal:@"ab"];
        });
        it(@"call stringByAppendingString: leak argument", ^{
            NSArray *arguments = @[];
            [[theBlock(^{
                callSelector(nil, @"stringByAppendingString:", arguments, str, NO);
            }) should] raiseWithName:@"LuaPatchInvalidArgumentCountException"];
        });
        it(@"call stringByAppendingString: too much argument",^{
            NSArray *arguments = @[@"b",@"c"];
            [[theBlock(^{
                callSelector(nil, @"stringByAppendingString:", arguments, str, NO);
            }) should] raiseWithName:@"LuaPatchInvalidArgumentCountException"];
        });
        it(@"call stringByAppendingString: error argument",^{
            id arguament = [NSArray new];
            NSArray *arguments = @[arguament];//NSInvalidArgumentException
            [[theBlock(^{
                callSelector(nil, @"stringByAppendingString:", arguments, str, NO);
            }) should] raiseWithName:@"NSInvalidArgumentException"];
//            callSelector(nil, @"stringByAppendingString:", arguments, str, NO);
        });
    });
    
    context(@"call callSuperI", ^{
        
    });
    
    context(@"call lua test", ^{
        __block lua_State *L;
        beforeAll(^{
            L = [ViewController getLuaState];
        });
        it(@"call lua test",^{
            NSLog(@"call lua test");
            chdir([[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"luaSource"].UTF8String);
            NSString *luaTestFile = [[NSBundle mainBundle] pathForResource:@"luaSource/unit_test/unitTest" ofType:@"lua"];
            int err = luaL_dofile(L, luaTestFile.UTF8String);//在运行完成后
            if(0 != err){
                luaL_error(L, "cannot compile the lua file: %s",lua_tostring(L, -1));
                return;
            }
        });
        it(@"a",^{
            NSLog(@"a");
        });
    });
});


SPEC_END

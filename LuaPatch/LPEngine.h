//
//  LPEngine.h
//  luaPatch
//
//  Created by 黄钊 on 2019/3/28.
//  Copyright © 2019 hz. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

struct lua_State;
typedef struct lua_State lua_State;

typedef enum{
    LPBoxingTypePoint,//普通指针
//    LPBoxingTypeString,//指向字符串的指针
}LPBoxingType;

//盒子类型
@interface LPBoxing : NSObject
@property LPBoxingType type;
@property void *pointer;
- (void *)unboxPointer;
@end


//向外部暴露接口，单元测试要调用
id callSelector(NSString *className, NSString *selectorName,NSArray *arguments,id instance,BOOL isSuper);

id callLuaMethodImplement(NSString *luaFunctionName,id instance,NSString *className,NSArray *paramList,char returnValueType);

//这个库加载的接口
int luaopen_luapatch_core(lua_State *L);

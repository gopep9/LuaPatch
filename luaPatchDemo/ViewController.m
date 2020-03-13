//
//  ViewController.m
//  luaPatch
//
//  Created by 黄钊 on 2019/3/28.
//  Copyright © 2019 hz. All rights reserved.
//

#import "ViewController.h"
#import "LPEngine.h"
#import "lauxlib.h"
#import "lualib.h"
#import "unistd.h"
#include <dlfcn.h>


static int setLuaPath(lua_State* L, const char* path);

static lua_State *L;

@interface ViewController ()

@end

@implementation ViewController

+(lua_State *)getLuaState{
    return L;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    L = luaL_newstate();
    luaL_openlibs(L);
    lua_settop(L, 0);
    
    //修复require找不到
    //https://stackoverflow.com/questions/22492741/lua-require-function-does-not-find-my-required-file-on-ios
    //https://www.gamedev.net/forums/topic/416378-changing-the-search-path-for-luas-require-from-c/
    //设置lua当前所在目录，为了让单元测试能找到对应的文件并且拼接字符串
    chdir([[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"luaSource"].UTF8String);
    NSLog(@"bundlePath is %@",[[NSBundle mainBundle] bundlePath]);
    setLuaPath(L,[[[NSBundle mainBundle] bundlePath] stringByAppendingString:@"/?.lua"].UTF8String);
    
    setLuaPath(L,[[[NSBundle mainBundle] bundlePath] stringByAppendingString:@"/luaSource/?.lua"].UTF8String);
    setLuaPath(L,[[[NSBundle mainBundle] bundlePath] stringByAppendingString:@"/luaSource/third_party/luarocks/?.lua"].UTF8String);
    setLuaPath(L,[[[NSBundle mainBundle] bundlePath] stringByAppendingString:@"/luaSource/third_party/luarocks/?/init.lua"].UTF8String);//问号是占位符，lua会用要require的字符串替代问号
    //lua加载c库
    int top = lua_gettop(L);
    luaL_getsubtable(L, LUA_REGISTRYINDEX, LUA_PRELOAD_TABLE);
    
    int luaopen_term_core(lua_State *L);
    lua_pushcfunction(L, luaopen_term_core);
    lua_setfield(L, top+1, "term.core");
    
    int luaopen_lfs (lua_State *L);
    lua_pushcfunction(L, luaopen_lfs);
    lua_setfield(L, top+1, "lfs");
    
    int luaopen_system_core(lua_State *L);
    lua_pushcfunction(L, luaopen_system_core);
    lua_setfield(L, top+1, "system.core");
    
    lua_pushcfunction(L, luaopen_luapatch_core);
    lua_setfield(L, top+1, "luapatch.core");
    
    lua_pop(L, 1);

    NSString *luaFilePath = [[NSBundle mainBundle] pathForResource:@"luaSource/main" ofType:@"lua"];
    
    int err = luaL_dofile(L, luaFilePath.UTF8String);
    if(0 != err){
        luaL_error(L, "cannot compile the lua file: %s",lua_tostring(L, -1));
        return;
    }
    [self updateViewController];
}

//必须的函数，用于给lua替换其实现，设置页面
-(void)updateViewController{
//    NSMutableArray *a = [NSMutableArray alloc]initWithObjects:<#(nonnull id), ...#>, nil
//    NSMutableArray *a = [[NSMutableArray alloc] initWithObjects:@"a"];
}

@end


static int setLuaPath(lua_State* L, const char* path) {
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "path"); // get field "path" from table at top of stack (-1)
    const char* cur_path = lua_tostring(L, -1); // grab path string from top of stack
    NSString *cur_path_nsstr = [NSString stringWithUTF8String:cur_path];
    cur_path_nsstr = [[[NSString stringWithUTF8String:path] stringByAppendingString:@";"] stringByAppendingString:cur_path_nsstr];
    lua_pop(L, 1); // get rid of the string on the stack we just pushed on line 5
    lua_pushstring(L, cur_path_nsstr.UTF8String); // push the new one
    lua_setfield(L, -2, "path"); // set the field "path" in table at -2 with value at top of stack
    lua_pop(L, 1); // get rid of package table from top of stack
    return 0; // all done!
}

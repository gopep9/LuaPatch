//
//  LPEngine.m
//  luaPatch
//
//  Created by 黄钊 on 2019/3/28.
//  Copyright © 2019 hz. All rights reserved.
//

//versionNumber必须每次修改该文件都加1
static const char * const versionStr = "1.7.0";
static const double versionNum = 10;

#if __has_feature(objc_arc)
//success
#else
#error this file is not in arc environment
#endif

#import "LPEngine.h"
#import <objc/runtime.h>
#import <objc/message.h>

#if TARGET_OS_IPHONE
//#import <UIKit/UIApplication.h>
#endif

#import "lauxlib.h"
#import "lualib.h"

static NSObject *_nilObj;//一个自定义的oc对象，用于代表空对象在oc层和js层传递，代表nil
static NSObject *_nullObj;//代表[NSNull null]
static NSMutableDictionary *_registeredStruct;//被注册过的数据结构，对于每个被注册的数据结构，这里面包含每个键的数据大小
//static NSMutableArray *_ocStructArray
static lua_State *_L;
static NSMutableDictionary *_currInvokeSuperClsName;// 键值例子是 _LPSUPER_funcInstance2

static JSContext *_context;//一个js的上下文，现在暂时只有传oc的struct的时候才会用这个东西
static NSMutableDictionary *_LuaOverideMethods;//存放被lua覆盖的方法，分别用类名和方法名进行索引
static NSRecursiveLock *_LPMethodForwardCallLock;//一个时刻只能有一个线程访问lua
static NSMutableDictionary *_propKeys;
static void (^_exceptionBlock)(NSString *log) = ^void(NSString *log) {
    NSCAssert(NO, log);
};

static id invokeVariableParameterMethod(NSMutableArray *origArgumentsList, NSMethodSignature *methodSignature, id sender, SEL selector);

static void overrideMethod(Class cls, NSString *selectorName, NSString *luaFunctionName/*lua对应的functionName*/, BOOL isClassMethod, const char *typeDescription);

static id genCallbackBlock(NSString *funcSignature,NSString *luaFunctionName);

//static const char *genSignature(const char *);

@implementation LPBoxing

#define LPBOXING_GEN(_name, _prop, _type) \
+ (instancetype)_name:(_type)obj  \
{   \
LPBoxing *boxing = [[LPBoxing alloc] init]; \
boxing._prop = obj;   \
return boxing;  \
}

LPBOXING_GEN(boxPointer, pointer, void *)

- (void *)unboxPointer
{
    return self.pointer;
}
@end

static NSString *trim(NSString *string)
{
    return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *extractStructName(NSString *typeEncodeString)
{
    NSArray *array = [typeEncodeString componentsSeparatedByString:@"="];
    NSString *typeString = array[0];
    int firstValidIndex = 0;
    for (int i = 0; i< typeString.length; i++) {
        char c = [typeString characterAtIndex:i];
        if (c == '{' || c=='_') {
            firstValidIndex++;
        }else {
            break;
        }
    }
    return [typeString substringFromIndex:firstValidIndex];
}

static const void *propKey(NSString *propName) {
    if (!_propKeys) _propKeys = [[NSMutableDictionary alloc] init];
    id key = _propKeys[propName];
    if (!key) {
        key = [propName copy];
        [_propKeys setObject:key forKey:propName];
    }
    return (__bridge const void *)(key);
}
static id getPropIMP(id slf, SEL selector, NSString *propName) {
    return objc_getAssociatedObject(slf, propKey(propName));
}
static void setPropIMP(id slf, SEL selector, id val, NSString *propName) {
    objc_setAssociatedObject(slf, propKey(propName), val, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

//是否打log

static int isPrintLog = 0;


static void _printLog(NSString *str){
    if(isPrintLog){
        NSLog(@"%@",str);
    }
}

#define printLog(...) _printLog([NSString stringWithFormat:__VA_ARGS__])

static int setPrintLog(lua_State *L){
    isPrintLog = lua_toboolean(L,1);
    return 0;
}

//生成oc函数签名
static const char *genFunctionSignature(const char *typesCStr){
    NSString *types = [NSString stringWithUTF8String:typesCStr];
    static NSMutableDictionary *typeSignatureDict;
    if (!typeSignatureDict){
        typeSignatureDict = [NSMutableDictionary new];
#define LP_DEFINE_TYPE_SIGNATURE(_type) \
[typeSignatureDict setObject:@[[NSString stringWithUTF8String:@encode(_type)], @(sizeof(_type))] forKey:@#_type];
        
        LP_DEFINE_TYPE_SIGNATURE(id);
        LP_DEFINE_TYPE_SIGNATURE(BOOL);
        LP_DEFINE_TYPE_SIGNATURE(int);
        LP_DEFINE_TYPE_SIGNATURE(void);
        LP_DEFINE_TYPE_SIGNATURE(char);
        LP_DEFINE_TYPE_SIGNATURE(short);
        LP_DEFINE_TYPE_SIGNATURE(unsigned short);
        LP_DEFINE_TYPE_SIGNATURE(unsigned int);
        LP_DEFINE_TYPE_SIGNATURE(long);
        LP_DEFINE_TYPE_SIGNATURE(unsigned long);
        LP_DEFINE_TYPE_SIGNATURE(long long);
        LP_DEFINE_TYPE_SIGNATURE(unsigned long long);
        LP_DEFINE_TYPE_SIGNATURE(float);
        LP_DEFINE_TYPE_SIGNATURE(double);
        LP_DEFINE_TYPE_SIGNATURE(bool);
        LP_DEFINE_TYPE_SIGNATURE(size_t);
        LP_DEFINE_TYPE_SIGNATURE(CGFloat);
        LP_DEFINE_TYPE_SIGNATURE(CGSize);
        LP_DEFINE_TYPE_SIGNATURE(CGRect);
        LP_DEFINE_TYPE_SIGNATURE(CGPoint);
        LP_DEFINE_TYPE_SIGNATURE(CGVector);
        LP_DEFINE_TYPE_SIGNATURE(NSRange);
        LP_DEFINE_TYPE_SIGNATURE(NSInteger);
        LP_DEFINE_TYPE_SIGNATURE(Class);
        LP_DEFINE_TYPE_SIGNATURE(SEL);
        LP_DEFINE_TYPE_SIGNATURE(void*);
        LP_DEFINE_TYPE_SIGNATURE(void *);
    }
    NSArray *lt = [types componentsSeparatedByString:@"_"];
    
    __autoreleasing NSString *funcSignature = [@"@0:" stringByAppendingString:[@(sizeof(void *)) stringValue]];
    
    NSInteger size = sizeof(void *) + sizeof(void *);//函数指针的大小
    
    //只有返回值的特殊情况
    if(lt.count == 1){
        NSString *t = trim(lt[0]);
        NSString *type = typeSignatureDict[typeSignatureDict[t] ? t : @"id"][0];
        funcSignature = [[NSString stringWithFormat:@"%@%@",type,[@(size) stringValue]] stringByAppendingString:funcSignature];
        return funcSignature.UTF8String;
    }
    
    for(NSInteger i = 1; i < lt.count;){
        NSString *t = trim(lt[i]);
        NSString *type = typeSignatureDict[typeSignatureDict[t] ? t : @"id"][0];//0位是变量类型名称（简写，例如i代表int v代表void），1位是变量大小
        if ( i == 0)
        {
            funcSignature = [[NSString stringWithFormat:@"%@%@",type,[@(size) stringValue]] stringByAppendingString:funcSignature];
            break;
        }
        funcSignature = [funcSignature stringByAppendingString:[NSString stringWithFormat:@"%@%@", type, [@(size) stringValue]]];
        size += [typeSignatureDict[typeSignatureDict[t] ? t : @"id"][1] integerValue];
        i = (i != lt.count - 1) ? i + 1 : 0;
    }
    return funcSignature.UTF8String;
}


//生成block的签名
static const char *genBlockSignature(const char *typesCStr){
    NSString *types = [NSString stringWithUTF8String:typesCStr];
    static NSMutableDictionary *typeSignatureDict;
    if (!typeSignatureDict){
        typeSignatureDict = [NSMutableDictionary new];
#define LP_DEFINE_TYPE_SIGNATURE(_type) \
[typeSignatureDict setObject:@[[NSString stringWithUTF8String:@encode(_type)], @(sizeof(_type))] forKey:@#_type];
        
        LP_DEFINE_TYPE_SIGNATURE(id);
        LP_DEFINE_TYPE_SIGNATURE(BOOL);
        LP_DEFINE_TYPE_SIGNATURE(int);
        LP_DEFINE_TYPE_SIGNATURE(void);
        LP_DEFINE_TYPE_SIGNATURE(char);
        LP_DEFINE_TYPE_SIGNATURE(short);
        LP_DEFINE_TYPE_SIGNATURE(unsigned short);
        LP_DEFINE_TYPE_SIGNATURE(unsigned int);
        LP_DEFINE_TYPE_SIGNATURE(long);
        LP_DEFINE_TYPE_SIGNATURE(unsigned long);
        LP_DEFINE_TYPE_SIGNATURE(long long);
        LP_DEFINE_TYPE_SIGNATURE(unsigned long long);
        LP_DEFINE_TYPE_SIGNATURE(float);
        LP_DEFINE_TYPE_SIGNATURE(double);
        LP_DEFINE_TYPE_SIGNATURE(bool);
        LP_DEFINE_TYPE_SIGNATURE(size_t);
        LP_DEFINE_TYPE_SIGNATURE(CGFloat);
        LP_DEFINE_TYPE_SIGNATURE(CGSize);
        LP_DEFINE_TYPE_SIGNATURE(CGRect);
        LP_DEFINE_TYPE_SIGNATURE(CGPoint);
        LP_DEFINE_TYPE_SIGNATURE(CGVector);
        LP_DEFINE_TYPE_SIGNATURE(NSRange);
        LP_DEFINE_TYPE_SIGNATURE(NSInteger);
        LP_DEFINE_TYPE_SIGNATURE(Class);
        LP_DEFINE_TYPE_SIGNATURE(SEL);
        LP_DEFINE_TYPE_SIGNATURE(void*);
        LP_DEFINE_TYPE_SIGNATURE(void *);
    }
    NSArray *lt = [types componentsSeparatedByString:@"_"];
    
    __autoreleasing NSString *funcSignature = @"@?0";
    
    NSInteger size = sizeof(void *);//函数指针的大小
    
    //只有返回值的特殊情况
    if(lt.count == 1){
        NSString *t = trim(lt[0]);
        NSString *type = typeSignatureDict[typeSignatureDict[t] ? t : @"id"][0];
        funcSignature = [[NSString stringWithFormat:@"%@%@",type,[@(size) stringValue]] stringByAppendingString:funcSignature];
        return funcSignature.UTF8String;
    }
    
    for(NSInteger i = 1; i < lt.count;){
        NSString *t = trim(lt[i]);
        NSString *type = typeSignatureDict[typeSignatureDict[t] ? t : @"id"][0];//0位是变量类型名称（简写，例如i代表int v代表void），1位是变量大小
        if ( i == 0)
        {
            funcSignature = [[NSString stringWithFormat:@"%@%@",type,[@(size) stringValue]] stringByAppendingString:funcSignature];
            break;
        }
        funcSignature = [funcSignature stringByAppendingString:[NSString stringWithFormat:@"%@%@", type, [@(size) stringValue]]];
        size += [typeSignatureDict[typeSignatureDict[t] ? t : @"id"][1] integerValue];
        i = (i != lt.count - 1) ? i + 1 : 0;
    }
    return funcSignature.UTF8String;
}


//定义一个类，调用这个函数后不存在的类会被创建，存在的类会添加getProp: 等方法
static void defineClassInOC(NSString *className,NSString *superClassName,NSArray *protocols){
    printLog(@"call defineClassInOC className:%@ superClassName:%@",className,superClassName);
    Class cls = NSClassFromString(className);
    if(!cls){
        //类还不存在，需要创建
        Class superCls = NSClassFromString(superClassName);
        if(!superCls){
            printLog(@"defineClass can't find super class");
            return;
        }
        cls = objc_allocateClassPair(superCls, className.UTF8String, 0);
        objc_registerClassPair(cls);
    }
    
    if(protocols.count > 0){
        for (NSString* protocolName in protocols) {
            Protocol *protocol = objc_getProtocol([trim(protocolName) cStringUsingEncoding:NSUTF8StringEncoding]);
            class_addProtocol (cls, protocol);
        }
    }
    class_addMethod(cls, @selector(getProp:), (IMP)getPropIMP, genFunctionSignature("id_id"));
    class_addMethod(cls, @selector(setProp:forKey:), (IMP)setPropIMP, genFunctionSignature("void_id_id"));
}


//这里的className务必传真实的className，传父类的className可能会有错误，isSuper应该是假如指定需要调用父类的函数时要加上这个标记，例如[super init];
id callSelector(NSString *className, NSString *selectorName,NSArray *arguments,id instance,BOOL isSuper){
    if([selectorName isEqual:@"view"]){
        int a = 1;
    }
    printLog(@"callSelect className:%@\n selectorName:%@\n arguments:%@\n isSuper:%d",className,selectorName,arguments,isSuper); //这里打印instance可能会导致闪退，因此跳过instance的打印
    //假如instance是个nil的话，直接返回nil
    if(instance == _nilObj){
        return _nilObj;
    }
    
    Class cls = instance ? [instance class] : NSClassFromString(className);
    SEL selector = NSSelectorFromString(selectorName);
    
    NSString *superClassName = nil;
    NSString *superSelectorName = nil;
    if(isSuper){
        superSelectorName = [NSString stringWithFormat:@"SUPER_%@", selectorName];
        SEL superSelector = NSSelectorFromString(superSelectorName);
                
        Class superCls = [cls superclass];
        
        Method superMethod = class_getInstanceMethod(superCls, selector);
        IMP superIMP = method_getImplementation(superMethod);
        
        //给本类添加一个SUPER_开头的方法，实现是对应的父类实现
        class_addMethod(cls, superSelector, superIMP, method_getTypeEncoding(superMethod));
        //假如是lua有在父类重定义过这个东西，那么让super方法指向父类重定义的lua函数
        NSString *LPSelectorName = [NSString stringWithFormat:@"_LP%@",selectorName];
        NSString *luaFunctionName = _LuaOverideMethods[superCls][LPSelectorName];
        if(luaFunctionName){
            printLog(@"call super method and find lua method");
            overrideMethod(cls, superSelectorName, luaFunctionName, NO, NULL);
        }
        selector = superSelector;
        superClassName = NSStringFromClass(superCls);
        printLog(@"callSelect super change selector:%@ superClassName:%@",NSStringFromSelector(selector),superClassName);
    }
    
    NSInvocation *invocation;
    NSMethodSignature *methodSignature;
    
    if(instance){
        //对实例调用方法
        methodSignature = [cls instanceMethodSignatureForSelector:selector];
        if (!methodSignature){
            _exceptionBlock([NSString stringWithFormat:@"unrecognized selector %@ for instance %@", selectorName, instance]);
            return nil;
        }
        invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
        [invocation setTarget:instance];
    }else{
        methodSignature = [cls methodSignatureForSelector:selector];
        if(!methodSignature){
            _exceptionBlock([NSString stringWithFormat:@"unrecognized selector %@ for class %@", selectorName, className]);
            return nil;
        }
        invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
        [invocation setTarget:cls];
    }
    [invocation setSelector:selector];
    
    NSUInteger numberOfArguments = methodSignature.numberOfArguments;
    NSInteger inputArguments = [arguments count];
    //实际上传入的参数个数大于需求的参数个数
    if (inputArguments > numberOfArguments - 2){
        printLog(@"callSelector inputArguments > numberOfArguments - 2");
        id sender = instance != nil ? instance : cls;
        //遍历参数
        NSMutableArray *argumentsObj = [[NSMutableArray alloc] init];
        for(id valObj in arguments){
            if([valObj isKindOfClass:LPBoxing.class]){
                LPBoxing *valObjBoxing = valObj;
                id value = [valObjBoxing unboxPointer];
                if(value == _nullObj){
                    value = [NSNull null];
                    [argumentsObj addObject:value];
                }else{
                    //是nilobj的话也直接加进去
                    [argumentsObj addObject:value];
                }
            }
            else if([valObj isKindOfClass:NSString.class]){
                __autoreleasing NSString *valStr = valObj;
                [argumentsObj addObject:valStr];
            }else{
                [argumentsObj addObject:valObj];
            }
        }
        id result = invokeVariableParameterMethod(argumentsObj,methodSignature,sender,selector);
        return result;
    }
    else if(inputArguments < numberOfArguments - 2){
        @throw [NSException exceptionWithName:@"LuaPatchInvalidArgumentCountException" reason:@"inputArguments < numberOfArguments - 2" userInfo:nil];
    }
    //遍历所有参数
    for( NSUInteger i = 2; i < numberOfArguments; i++){
        const char *argumentType = [methodSignature getArgumentTypeAtIndex:i];
        printLog(@"callSelect argumentType is %s",argumentType);
        id valObj = arguments[i-2];
        //按函数的签名配置参数
        switch (argumentType[0] == 'r' ? argumentType[1] : argumentType[0]) {
                //js中全部使用使用id来持有oc的类型，之后再根据函数的签名转化为实际的类型
                //详细列表可以看看苹果文档 https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html#//apple_ref/doc/uid/TP40008048-CH100-SW1
#define LP_CALL_ARG_CASE(_typeString, _type, _selector) \
case _typeString: {                              \
_type value = [valObj _selector];                     \
[invocation setArgument:&value atIndex:i];\
break; \
}
                //基本类型
                LP_CALL_ARG_CASE('c', char, charValue)
                LP_CALL_ARG_CASE('C', unsigned char, unsignedCharValue)
                LP_CALL_ARG_CASE('s', short, shortValue)
                LP_CALL_ARG_CASE('S', unsigned short, unsignedShortValue)
                LP_CALL_ARG_CASE('i', int, intValue)
                LP_CALL_ARG_CASE('I', unsigned int, unsignedIntValue)
                LP_CALL_ARG_CASE('l', long, longValue)
                LP_CALL_ARG_CASE('L', unsigned long, unsignedLongValue)
                LP_CALL_ARG_CASE('q', long long, longLongValue)
                LP_CALL_ARG_CASE('Q', unsigned long long, unsignedLongLongValue)
                LP_CALL_ARG_CASE('f', float, floatValue)
                LP_CALL_ARG_CASE('d', double, doubleValue)
                LP_CALL_ARG_CASE('B', BOOL, boolValue)
                
            case ':':{//lua用字符持有SEL
                if([valObj isKindOfClass:NSString.class]){
                    __autoreleasing NSString *valStr = valObj;
                    SEL value = NSSelectorFromString(valStr);
                    [invocation setArgument:&value atIndex:i];
                }
                break;
            }
            case '{':{//结构体，js中使用字典保存结构体，传到oc中后要手动转化为结构体
                //这里暂时只兼容几种oc类型CGRect、CGPoint、CGSize、NSRange
                //结构体暂时用jsvalue指针保存
                
                NSString *typeString = extractStructName([NSString stringWithUTF8String:argumentType]);
                JSValue *val = [((LPBoxing *)valObj) unboxPointer];
                
#define LP_CALL_ARG_STRUCT(_type, _methodName) \
if ([typeString rangeOfString:@#_type].location != NSNotFound) {    \
_type value = [val _methodName];  \
[invocation setArgument:&value atIndex:i];  \
break; \
}
                LP_CALL_ARG_STRUCT(CGRect, toRect)
                LP_CALL_ARG_STRUCT(CGPoint, toPoint)
                LP_CALL_ARG_STRUCT(CGSize, toSize)
                LP_CALL_ARG_STRUCT(NSRange, toRange)
                
                break;
            }
            case '*'://char * 字符串
            case '^':{//void * 指针
                if([valObj isKindOfClass:LPBoxing.class]){
                    //在oc封装的类中取出指针
                    void *value = [((LPBoxing *)valObj) unboxPointer];
                    [invocation setArgument:&value atIndex:i];
                }else if([valObj isKindOfClass:NSString.class]){
                    __autoreleasing NSString *valStr = valObj;
                    const char *value = valStr.UTF8String;
                    [invocation setArgument:&value atIndex:i];
                }
                break;
            }
            case '#':{//class对象
                Class value = [((LPBoxing *)valObj) unboxPointer];
                [invocation setArgument:&value atIndex:i];
                break;
            }
            case '@':{//oc对象，这里支持在lua传一个字符串，之后在这里转化为oc对象
                if([valObj isKindOfClass:LPBoxing.class]){//假如是用boxing包装的类型
                    LPBoxing *valObjBoxing = valObj;
                    printLog(@"value is oc object");
                    id value = [valObjBoxing unboxPointer];
                    if(value == _nullObj){//是null
                        printLog(@"value is null obj");
                        value = [NSNull null];
                        [invocation setArgument:&value atIndex:i];
                        break;
                    }else if(value == _nilObj){
                                 printLog(@"value is nil obj");
                                 value = nil;
                                 [invocation setArgument:&value atIndex:i];
                                 break;
                             }
                    [invocation setArgument:&value atIndex:i];
                    break;
                }else if([valObj isKindOfClass:NSString.class]){
                    __autoreleasing NSString *valStr = valObj;
                    printLog(@"value is NSString");
                    [invocation setArgument:&valStr atIndex:i];
                    break;
                }
                else{
                    //数字之类的，直接设置
                    printLog(@"value is NSNumber");
                    [invocation setArgument:&valObj atIndex:i];
                }
                break;
            }
            default:{//其它类型，一般不会跑到这里
                printLog(@"callSelector no support type %c",argumentType[0] == 'r' ? argumentType[1] : argumentType[0]);
                break;
            }
        }
    }
    printLog(@"callSelector before invocation invoke");
    if(superClassName) _currInvokeSuperClsName[[NSString stringWithFormat:@"_LPSUPER_%@", selectorName]] = superClassName;
    [invocation invoke];
    if(superClassName) [_currInvokeSuperClsName removeObjectForKey:[NSString stringWithFormat:@"_LPSUPER_%@", selectorName]];
    printLog(@"callSelector after invocation invoke");
    
    char returnType[255];
    
    strcpy(returnType, [methodSignature methodReturnType]);
    printLog(@"callSelect returnType is %s",returnType);
    __autoreleasing id returnValue = nil;
    
    
    switch (returnType[0] == 'r' ? returnType[1] : returnType[0]) {
            //是基本类型对象的话返回NSumber对象的指针，假如lua需要解析这些参数的话注册几个函数给lua
#define LP_CALL_RET_CASE(_typeString, _type)\
case _typeString: {\
_type tempResultSet;\
[invocation getReturnValue:&tempResultSet];\
returnValue = @(tempResultSet);\
break;\
}
            
            LP_CALL_RET_CASE('c', char)
            LP_CALL_RET_CASE('C', unsigned char)
            LP_CALL_RET_CASE('s', short)
            LP_CALL_RET_CASE('S', unsigned short)
            LP_CALL_RET_CASE('i', int)
            LP_CALL_RET_CASE('I', unsigned int)
            LP_CALL_RET_CASE('l', long)
            LP_CALL_RET_CASE('L', unsigned long)
            LP_CALL_RET_CASE('q', long long)
            LP_CALL_RET_CASE('Q', unsigned long long)
            LP_CALL_RET_CASE('f', float)
            LP_CALL_RET_CASE('d', double)
            LP_CALL_RET_CASE('B', BOOL)
            
        case '{':{//返回结构体，只考虑oc中的四种结构体
            NSString *typeString = extractStructName([NSString stringWithUTF8String:returnType]);
#define LP_CALL_RET_STRUCT(_type, _methodName) \
if ([typeString rangeOfString:@#_type].location != NSNotFound) {    \
_type result;   \
[invocation getReturnValue:&result];    \
return [JSValue _methodName:result inContext:_context];    \
}
            LP_CALL_RET_STRUCT(CGRect, valueWithRect)
            LP_CALL_RET_STRUCT(CGPoint, valueWithPoint)
            LP_CALL_RET_STRUCT(CGSize, valueWithSize)
            LP_CALL_RET_STRUCT(NSRange, valueWithRange)
        }
        case '@':{
            void *result;
            [invocation getReturnValue:&result];

            if([selectorName isEqualToString:@"alloc"] || [selectorName isEqualToString:@"new"] || [selectorName isEqualToString:@"copy"] || [selectorName isEqualToString:@"mutableCopy"]){
                returnValue = (__bridge_transfer id)result;
                printLog(@"callSelector return value need __bridge_transfer");
            }else{
                returnValue = (__bridge id)result;
            }
            if(returnValue == nil)//假如返回值是nil，返回nilObj给lua
            {
                printLog(@"callSelector return value is nil");
                returnValue = _nilObj;
            }
            break;
        }
        case '*':
        case '^':{//返回指针
            void *result;
            [invocation getReturnValue:&result];
            returnValue = [LPBoxing boxPointer:result];
            break;
        }
        case '#':{
            void *result;
            [invocation getReturnValue:&result];
            returnValue = (__bridge id)result;
            break;
        }
        case ':':{
            void *result;
            [invocation getReturnValue:&result];
            returnValue = NSStringFromSelector(result);
            break;
        }
        default:
            break;
    }
    return returnValue;
}

//获取lua注册过的函数，让oc在函数实际被调用的时候能重定向到lua函数
static NSString *getLuaFunctionInObjectHierachy(id slf, NSString *selectorName)
{
    Class cls = object_getClass(slf);
    NSString *class_name = NSStringFromClass(cls);
    printLog(@"getLuaFunctionInObjectHierachy class:%@ selectorName:%@",class_name,selectorName);
    if(_currInvokeSuperClsName[selectorName]){
        cls = NSClassFromString(_currInvokeSuperClsName[selectorName]);
        selectorName = [selectorName stringByReplacingOccurrencesOfString:@"_LPSUPER_" withString:@"_LP"];
    }
    NSString *luaFunctionName = _LuaOverideMethods[cls][selectorName];
    while (!luaFunctionName) {
        cls = class_getSuperclass(cls);
        if(!cls){
            printLog(@"getLuaFunctionInObjectHierachy can not find luaFunction");
            return nil;
        }
        luaFunctionName = _LuaOverideMethods[cls][selectorName];
    }
    printLog(@"getLuaFunctionInObjectHierachy find luaFunction %@",luaFunctionName);
    return luaFunctionName;
}

//调用原来的forwardInvocation方法
static void LPExecuteORIGForwardInvocation(id slf, SEL selector, NSInvocation *invocation)
{
    printLog(@"call LPExecuteORIGForwardInvocation select:%@ and invocation:%@",NSStringFromSelector(selector),invocation);
    SEL origForwardSelector = @selector(ORIGforwardInvocation:);
    
    if([slf respondsToSelector:origForwardSelector]){
        //对象本身能响应这个方法
        printLog(@"LPExecuteORIGForwardInvocation self respondsToSelector ORIGforwardInvocation:");
        NSMethodSignature *methodSignature = [slf methodSignatureForSelector:origForwardSelector];
        if (!methodSignature) {
            _exceptionBlock([NSString stringWithFormat:@"unrecognized selector -ORIGforwardInvocation: for instance %@", slf]);
            return;
        }
        NSInvocation *forwardInv= [NSInvocation invocationWithMethodSignature:methodSignature];
        [forwardInv setTarget:slf];
        [forwardInv setSelector:origForwardSelector];
        [forwardInv setArgument:&invocation atIndex:2];
        [forwardInv invoke];
    }else{
        //对象不能响应这个方法
        printLog(@"LPExecuteORIGForwardInvocation self can not respondsToSelector ORIGforwardInvocation:");
        Class superCls = [[slf class] superclass];
        printLog(@"LPExecuteORIGForwardInvocation superCls name %@",NSStringFromClass(superCls));
        Method superForwardMethod = class_getInstanceMethod(superCls, @selector(forwardInvocation:));
        void (*superForwardIMP)(id, SEL, NSInvocation *);
        superForwardIMP = (void (*)(id, SEL, NSInvocation *))method_getImplementation(superForwardMethod);
        superForwardIMP(slf, @selector(forwardInvocation:), invocation);// 父类没有实现的话会无限循环，没有解决方法
    }
}

//调用lua实现的类函数，或者是实例函数
id callLuaMethodImplement(NSString *luaFunctionName,id instance,NSString *className,NSArray *paramList,char returnValueType/*返回值类型*/){
    printLog(@"callLuaMethodImplement luaFunctionName:%@ className:%@ paramList:%@ returnValueType:%c",luaFunctionName,className,paramList,returnValueType);
    lua_getglobal(_L, luaFunctionName.UTF8String);
    
    if(instance){
        lua_pushlightuserdata(_L, (__bridge void *)(instance));
    }else{
        lua_pushstring(_L, className.UTF8String);
    }
    
    for(id param in paramList){
        if([param isKindOfClass:NSString.class])//字符串
        {
            NSString *str = param;
            lua_pushstring(_L, str.UTF8String);
        }else if([param isKindOfClass:NSNumber.class])//数字，bool，字符等类型，
        {
            NSNumber *num = param;
            lua_pushnumber(_L, num.doubleValue);
        }else if([param isKindOfClass:LPBoxing.class]){//指针
            LPBoxing *boxing = param;
            lua_pushlightuserdata(_L, [boxing unboxPointer]);
        }else{//oc对象，直接传指针给lua指针
            lua_pushlightuserdata(_L, (__bridge void *)(param));
        }
    }
    int ret = lua_pcall(_L, (int)paramList.count + 1, 1, 0);
    if (ret != 0){
        int t = lua_type(_L, -1);
        if(t == LUA_TSTRING){
            const char *err = lua_tostring(_L, -1);
            printLog(@"lua error in callLuaMethodImplement, error message is %s",err);
            printLog(@"luaFunctionName is %@\nclassName is %@\nparamList is %@",luaFunctionName,className,paramList);
        }
        lua_pop(_L, 1);
        return nil;
    }
    switch(returnValueType){
        case '@':{//oc对象
            //判断lua的返回类型
            if(lua_type(_L, -1) == LUA_TSTRING)
            {
                const char *retChar = lua_tostring(_L, -1);
                printLog(@"callLuaMethodImplement lua return string is %s",retChar);
                //判断是否是lua生成的block
                //字符串的情况
                lua_pop(_L, 1);
                return [NSString stringWithUTF8String:retChar];
            }else if(lua_type(_L, -1) == LUA_TLIGHTUSERDATA)
            {
                void *p = lua_touserdata(_L, -1);
                printLog(@"callLuaMethodImplement lua return point %p",p);
                lua_pop(_L, 1);
                return (__bridge id)p;
            }else if(lua_type(_L, -1) == LUA_TNUMBER){
                //这里兼容lua返回数字
                double retDouble = lua_tonumber(_L, -1);
                printLog(@"callLuaMethodImplement lua return number %f",retDouble);
                lua_pop(_L, 1);
                return @(retDouble);
            }
            break;
        }
        case 'd':{//double，返回number对象
            double doubleNum = lua_tonumber(_L, -1);
            lua_pop(_L, 1);
            NSNumber *num = @(doubleNum);
            return num;
            break;
        }
        case '*':{//指针
            void *p = lua_touserdata(_L, -1);
            lua_pop(_L, 1);
            LPBoxing *boxing = [LPBoxing boxPointer:p];
            boxing.type = LPBoxingTypePoint;
            return boxing;
            break;
        }
        case ':':{//返回一个SEL
            const char *str = (void*)lua_tostring(_L, -1);
            lua_pop(_L, 1);
            return [NSString stringWithUTF8String:str];
            break;
        }
    }
    return nil;
}

//重定义后的函数都跑到这里来
//lua函数接收参数的格式为
//1.假如是调用了类方法的话，那么第一个参数是类名，后面是参数对象
//2.假如是调用了实例方法的话，那么第一个参数是实例，后面是参数对象
//暂时只兼容返回oc对象和返回void，指针和基本类型
//参数类型兼容oc对象
static void LPForwardInvocation(__unsafe_unretained id assignSlf, SEL selector, NSInvocation *invocation){
    //这里的invocation.target好像是和assignSlf相等，不知道是否存在不相等的情况
    id slf = assignSlf;
    BOOL isBlock = [[assignSlf class] isSubclassOfClass : NSClassFromString(@"NSBlock")];
    printLog(@"call LPForwardInvocation selector:%@ invocation:%@ isBlock:%d",NSStringFromSelector(selector),invocation,isBlock);
    
    NSMethodSignature *methodSignature = [invocation methodSignature];
    NSInteger numberOfArguments = [methodSignature numberOfArguments];
    NSString *selectorName = isBlock ? @"" : NSStringFromSelector(invocation.selector);
    NSString *LPSelectorName = [NSString stringWithFormat:@"_LP%@",selectorName];//这个是被重定向后原来的实现的函数名
    
    NSString *luaFunctionName = isBlock ? objc_getAssociatedObject(assignSlf, "_LuaFunctionName") : getLuaFunctionInObjectHierachy(slf, LPSelectorName);
    
    if(!luaFunctionName){
        //没找到函数名，执行原来的函数
        printLog(@"LPForwardInvocation can not find luaFunction");
        LPExecuteORIGForwardInvocation(slf, selector, invocation);
        return;
    }
    
    NSMutableArray *argList = [[NSMutableArray alloc] init];
    
    id instance = nil;
    NSString *className = @"";
    if(!isBlock){
        if([slf class] == slf){
            //调用的是类方法，第一个参数是类名
            className = NSStringFromClass([slf class]);
            printLog(@"LPForwardInvocation call classMethod %@",className);
        }else{
            //调用的是实例方法，第一个参数是实例的指针
            printLog(@"LPForwardInvocation call instance method");
            instance = slf;
        }
    }else{
        // 是block的情况
        printLog(@"LPForwardInvocation call block");
        instance = slf;
    }
    for (NSUInteger i = isBlock ? 1 : 2; i < numberOfArguments; i++){
        const char *argumentType = [methodSignature getArgumentTypeAtIndex:i];
        printLog(@"LPForwardInvocation argumentType is %s",argumentType);
        switch (argumentType[0] == 'r' ? argumentType[1] : argumentType[0]) {
                //对于基本类型全部转为double返回给lua，lua再根据需求自己转化成希望的类型
#define LP_FWD_ARG_CASE(_typeChar, _type) \
case _typeChar: { \
_type arg; \
[invocation getArgument:&arg atIndex:i]; \
[argList addObject:@(arg)]; \
break; \
}
                LP_FWD_ARG_CASE('c', char)
                LP_FWD_ARG_CASE('C', unsigned char)
                LP_FWD_ARG_CASE('s', short)
                LP_FWD_ARG_CASE('S', unsigned short)
                LP_FWD_ARG_CASE('i', int)
                LP_FWD_ARG_CASE('I', unsigned int)
                LP_FWD_ARG_CASE('l', long)
                LP_FWD_ARG_CASE('L', unsigned long)
                LP_FWD_ARG_CASE('q', long long)
                LP_FWD_ARG_CASE('Q', unsigned long long)
                LP_FWD_ARG_CASE('f', float)
                LP_FWD_ARG_CASE('d', double)
                LP_FWD_ARG_CASE('B', BOOL)
            case '@':{
                __unsafe_unretained id arg;
                [invocation getArgument:&arg atIndex:i];
                if([arg isKindOfClass:NSClassFromString(@"NSBlock")]){
                    printLog(@"LPForwardInvocation value is block");
                    [argList addObject:(arg ? [arg copy]: _nilObj)];
                }else{
                    printLog(@"LPForwardInvocation value is oc object");
                    [argList addObject:arg ? arg: _nilObj];
                }
                break;
            }
            case '{':{
                //直接传空
                //暂时只支持4种oc的struct
                NSString *typeString = extractStructName([NSString stringWithUTF8String:argumentType]);
#define LP_FWD_ARG_STRUCT(_type, _transFunc) \
if ([typeString rangeOfString:@#_type].location != NSNotFound) {    \
_type arg; \
[invocation getArgument:&arg atIndex:i];    \
[argList addObject:[JSValue _transFunc:arg inContext:_context]];  \
break; \
}
                LP_FWD_ARG_STRUCT(CGRect, valueWithRect)
                LP_FWD_ARG_STRUCT(CGPoint, valueWithPoint)
                LP_FWD_ARG_STRUCT(CGSize, valueWithSize)
                LP_FWD_ARG_STRUCT(NSRange, valueWithRange)
                break;
            }
            case ':':{
                SEL selector;
                [invocation getArgument:&selector atIndex:i];
                [argList addObject:NSStringFromSelector(selector)];
                break;
            }
            case '^':
            case '*':{
                void *arg;
                [invocation getArgument:&arg atIndex:i];
                //指针的话要用包装类包装下，防止可能会对普通的指针调用retain
                LPBoxing *boxing = [LPBoxing boxPointer:arg];
                boxing.type=LPBoxingTypePoint;
                [argList addObject:boxing];
                break;
            }
            case '#':{
                Class arg;
                [invocation getArgument:&arg atIndex:i];
                [argList addObject:arg];
                break;
            }
            default:{
                printLog(@"error type %s",argumentType);
                break;
            }
        }
    }
    
    char returnType[255];
    strcpy(returnType, [methodSignature methodReturnType]);
    printLog(@"LPForwardInvocation returnType is %s",returnType);
    
    __autoreleasing id ret = nil;
    
    if(_currInvokeSuperClsName[LPSelectorName]){
        Class cls = NSClassFromString(_currInvokeSuperClsName[LPSelectorName]);
        NSString *tmpSelectorName = [[selectorName stringByReplacingOccurrencesOfString:@"_LPSUPER_" withString:@"_LP"] stringByReplacingOccurrencesOfString:@"SUPER_" withString:@"_LP"];
    //要调用的super函数没有在lua中实现，也没有在oc中实现（不然也不会跑到这里来），而且这个对象的的forwardInvocation:是被改写成LPForwardInvocation了，这时候只能调用callSelector了
        if(!_LuaOverideMethods[cls][tmpSelectorName]){
            NSString *ORIGSelectorName = [selectorName stringByReplacingOccurrencesOfString:@"SUPER_" withString:@"ORIG"];//这里是找回父类真实的定义，可能会有坑，需要用单元测试探究其原理，测试各种情况
            ret = callSelector(_currInvokeSuperClsName[LPSelectorName], ORIGSelectorName, argList, slf, NO);
        }
    }
    
    printLog(@"LPForwardInvocation before callLuaMethodImplement");
    switch (returnType[0] == 'r' ? returnType[1] : returnType[0]) {
        case '@'://返回oc对象
        case '#':
        {
            [_LPMethodForwardCallLock lock];
            ret = ret?ret:callLuaMethodImplement(luaFunctionName, instance, className, argList, '@');//调用lua函数
            [_LPMethodForwardCallLock unlock];
            if(ret == _nilObj){
                ret = nil;
            }
            [invocation setReturnValue:&ret];
            break;
        }
        case 'v'://不返回对象
        {
            [_LPMethodForwardCallLock lock];
            callLuaMethodImplement(luaFunctionName, instance, className, argList, 'v');
            [_LPMethodForwardCallLock unlock];
            break;
        }
        case '^':
        case '*':
        {
            [_LPMethodForwardCallLock lock];
            ret = ret?ret:callLuaMethodImplement(luaFunctionName, instance, className, argList, '*');
            LPBoxing *box = ret;
            [_LPMethodForwardCallLock unlock];
            void *ret = box.pointer;
            [invocation setReturnValue:&ret];
            break;
        }
        case ':':
        {
            [_LPMethodForwardCallLock lock];
            ret = ret?ret:callLuaMethodImplement(luaFunctionName, instance, className, argList, ':');
            [_LPMethodForwardCallLock unlock];
            SEL retSEL = NSSelectorFromString(ret);
            [invocation setReturnValue:&retSEL];
            break;
        }
        case '{':
        {
            NSString *typeString = extractStructName([NSString stringWithUTF8String:returnType]);
            [_LPMethodForwardCallLock lock];
            ret = ret?ret:callLuaMethodImplement(luaFunctionName, instance, className, argList, '@');
            JSValue *jsval = ret;
            [_LPMethodForwardCallLock unlock];
#define LP_FWD_RET_STRUCT(_type, _funcSuffix) \
if ([typeString rangeOfString:@#_type].location != NSNotFound) {    \
_type ret = [jsval _funcSuffix]; \
[invocation setReturnValue:&ret];\
break;  \
}
            LP_FWD_RET_STRUCT(CGRect, toRect)
            LP_FWD_RET_STRUCT(CGPoint, toPoint)
            LP_FWD_RET_STRUCT(CGSize, toSize)
            LP_FWD_RET_STRUCT(NSRange, toRange)
        }
#define LP_FWD_RET_CASE(_typeChar, _type, _typeSelector) \
case _typeChar:{ \
[_LPMethodForwardCallLock lock]; \
ret = ret?ret:callLuaMethodImplement(luaFunctionName, instance, className, argList, 'd'); \
NSNumber *num = ret; \
[_LPMethodForwardCallLock unlock]; \
_type ret = num._typeSelector; \
[invocation setReturnValue:&ret]; \
break;\
}
            LP_FWD_RET_CASE('c', char, charValue)
            LP_FWD_RET_CASE('C', unsigned char, unsignedCharValue)
            LP_FWD_RET_CASE('s', short, shortValue)
            LP_FWD_RET_CASE('S', unsigned short, unsignedShortValue)
            LP_FWD_RET_CASE('i', int, intValue)
            LP_FWD_RET_CASE('I', unsigned int, unsignedIntValue)
            LP_FWD_RET_CASE('l', long, longValue)
            LP_FWD_RET_CASE('L', unsigned long, unsignedLongValue)
            LP_FWD_RET_CASE('q', long long, longLongValue)
            LP_FWD_RET_CASE('Q', unsigned long long, unsignedLongLongValue)
            LP_FWD_RET_CASE('f', float, floatValue)
            LP_FWD_RET_CASE('d', double, doubleValue)
            LP_FWD_RET_CASE('B', BOOL, boolValue)
            
        default:
            break;
    }
    printLog(@"LPForwardInvocation after callLuaMethodImplement");
}

//初始化保存lua函数的数组
static void _initLPOverideMethods(Class cls){
    printLog(@"call _initLPOverideMethods with class %@",NSStringFromClass(cls));
    if(!_LuaOverideMethods){
        printLog(@"init _LuaOverideMethods");
        _LuaOverideMethods = [[NSMutableDictionary alloc] init];
    }
    if(!_LuaOverideMethods[cls]){
        printLog(@"init _LuaOverideMethods with class %@",NSStringFromClass(cls));
        _LuaOverideMethods[(id<NSCopying>)cls] = [[NSMutableDictionary alloc] init];
    }
}

//改写oc函数
static void overrideMethod(Class cls, NSString *selectorName, NSString *luaFunctionName/*lua对应的functionName*/, BOOL isClassMethod, const char *typeDescription){
    printLog(@"call overrideMethod className:%@ selectorName:%@ luaFunctionName:%@ isClassMethod:%d typeDescription:%s",NSStringFromClass(cls),selectorName,luaFunctionName,isClassMethod,typeDescription);
    SEL selector = NSSelectorFromString(selectorName);
    const char *typeSignature = "";
    if(!typeDescription){
        Method method = class_getInstanceMethod(cls, selector);
        typeSignature = (char *)method_getTypeEncoding(method);
    }else{
        typeSignature = genFunctionSignature(typeDescription);
        int a = 1;
    }
    IMP originalImp = class_getInstanceMethod(cls, selector)?class_getMethodImplementation(cls, selector):NULL;
    IMP msgForwardIMP = _objc_msgForward;
    
    //某些特殊的架构要发送到_objc_msgForward_stret
    //对于ios是否可以去掉这个代码？
#if !defined(__arm64__)
    if (typeSignature[0] == '{') {
        //In some cases that returns struct, we should use the '_stret' API:
        //http://sealiesoftware.com/blog/archive/2008/10/30/objc_explain_objc_msgSend_stret.html
        //NSMethodSignature knows the detail but has no API to return, we can only get the info from debugDescription.
        NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:typeSignature];
        if ([methodSignature.debugDescription rangeOfString:@"is special struct return? YES"].location != NSNotFound) {
            msgForwardIMP = (IMP)_objc_msgForward_stret;
        }
    }
#endif
    if(class_getMethodImplementation(cls, @selector(forwardInvocation:)) != (IMP)LPForwardInvocation)
    {
        //设置类的forwardInvocation: 发送到自定义的函数中
        printLog(@"overrideMethod className %@ forwardInvocation: implementation is not LPForwardInvocation",NSStringFromClass(cls));
        IMP originalForwardImp = class_replaceMethod(cls, @selector(forwardInvocation:), (IMP)LPForwardInvocation, genFunctionSignature("void_id"));
        if(originalForwardImp){
            printLog(@"overrideMethod className %@ set select ORIGforwardInvocation:",NSStringFromClass(cls));
            class_addMethod(cls, @selector(ORIGforwardInvocation:), originalForwardImp, genFunctionSignature("void_id"));//假如多次调用的话ORIGforwardInvocation:也是指向LPForwardInvocation了
        }
    }
    
    if(class_respondsToSelector(cls, selector))
    {
        //类实例本身能响应重定向的方法
        printLog(@"overrideMethod className %@ responds selector %@",NSStringFromClass(cls),selectorName);
        NSString *originalSelectorName = [NSString stringWithFormat:@"ORIG%@", selectorName];
        SEL originalSelector = NSSelectorFromString(originalSelectorName);
        if(!class_respondsToSelector(cls, originalSelector)){
            //本方法的ORIG方法还没有实现，使用class_addMethod给方法添加实现
            printLog(@"overrideMethod redirect className %@ selector %@ to %@",NSStringFromClass(cls),selectorName,originalSelectorName);
            class_addMethod(cls, originalSelector, originalImp, typeSignature);
        }
    }
    NSString *LPSelectorName = [NSString stringWithFormat:@"_LP%@",selectorName];
    
    _initLPOverideMethods(cls);
    _LuaOverideMethods[cls][LPSelectorName] = luaFunctionName;
    class_replaceMethod(cls, selector, msgForwardIMP, typeSignature);//改写之前的接口执行_objc_msgForward
}

//block 创建一个有效的方法签名 参考__block_impl的实现
static NSMethodSignature *block_methodSignatureForSelector(id self, SEL _cmd, SEL aSelector){
    printLog(@"block_methodSignatureForSelector");
    uint8_t *p = (uint8_t *)((__bridge void *)self);
    p += sizeof(void *)*2 + sizeof(int32_t) *2;
    void *p2 = *(void **)p;//这里的p是指向block_desc，p2就是block_desc，也就是__main_block_desc_0
    p = p2;
    p += sizeof(uintptr_t) * 2;//c函数指针偏移两个uintptr_t后指向签名的指针
    const char **signature = (const char **)p;
    return [NSMethodSignature signatureWithObjCTypes:*signature];
}


static id genCallbackBlock(NSString *types,NSString *luaFunctionName){
    printLog(@"call genCallbackBlock types:%@ luaFunctionName:%@",types,luaFunctionName);
    void (^block)(void) = ^(void){};//这个block是不会访问其执行堆栈的指针的，因此就算这个block是个堆栈block也没问题，说不定就是用了这样的特性来重定向的
    uint8_t *p = (uint8_t *)((__bridge void*)block);
    p += sizeof(void *) + sizeof(int32_t) *2;
    void(**invoke)(void) = (void (**)(void))p;//p指向FuncPtr变量
    
    p += sizeof(void *);//移动p指向block_desc
    void *p2 = *(void **)p;//解引用p，现在p2指向block_desc中的第一个变量reserved
    p = p2;
    p += sizeof(uintptr_t) * 2;//跳过block_desc中的reserved和Block_size，现在指向的指针指向签名字符串
    const char **signature = (const char **)p;
    
    NSString *funcSignature = [NSString stringWithUTF8String: genBlockSignature(types.UTF8String)];
    
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    if ([funcSignature UTF8String][0] == '{') {//返回结构体，在非arm64的情况下要特殊处理
        //In some cases that returns struct, we should use the '_stret' API:
        //http://sealiesoftware.com/blog/archive/2008/10/30/objc_explain_objc_msgSend_stret.html
        //NSMethodSignature knows the detail but has no API to return, we can only get the info from debugDescription.
        NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:[funcSignature UTF8String]];
        if ([methodSignature.debugDescription rangeOfString:@"is special struct return? YES"].location != NSNotFound) {
            msgForwardIMP = (IMP)_objc_msgForward_stret;
        }
    }
#endif
    *invoke = (void *)msgForwardIMP;
    const char *fs = [funcSignature UTF8String];
    char *s = malloc(strlen(fs));//必定会泄露，没有解决方法
    strcpy(s, fs);
    *signature = s;//改写block中c函数签名
    objc_setAssociatedObject(block, "_LuaFunctionName", luaFunctionName, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = NSClassFromString(@"NSBlock");
#define LP_HOOK_METHOD(selector, func) {Method method = class_getInstanceMethod([NSObject class], selector); \
BOOL success = class_addMethod(cls, selector, (IMP)func, method_getTypeEncoding(method)); \
if (!success) { class_replaceMethod(cls, selector, (IMP)func, method_getTypeEncoding(method));}}
        LP_HOOK_METHOD(@selector(methodSignatureForSelector:), block_methodSignatureForSelector);
        LP_HOOK_METHOD(@selector(forwardInvocation:), LPForwardInvocation);
        //给NSBlock设置methodSignatureForSelector:和methodSignatureForSelector:重定向到自定义的函数
        printLog(@"redirect NSBlock methodSignatureForSelector: to block_methodSignatureForSelector and forwardInvocation: to LPForwardInvocation");
    });
    return block;
}


//构建传入callSelector中的参数序列
NSArray *buildCallSelectorParams(lua_State *L,int argStartIndex){
    printLog(@"call buildCallSelectorParams");
    NSMutableArray *paramsArray = [[NSMutableArray alloc]init];
    int argc = lua_gettop(L);
    for(int i = argStartIndex; i < argc; i += 2){
        const char *argType = luaL_checkstring(L, i+1);
        //lua的类型有bool number string userdata
        if(strcmp(argType, "@") == 0){//oc对象（class也可以用这个）或者是其它的指针
            void * point = lua_touserdata(L, i+2);
            LPBoxing *arg = [LPBoxing boxPointer:point];
            arg.type = LPBoxingTypePoint;//声明里面是oc对象或者是普通指针
            [paramsArray addObject:arg];
        }else if(strcmp(argType, "*") == 0){//字符串
            const char *pointArg = luaL_checkstring(L, i+2);
            [paramsArray addObject:[NSString stringWithUTF8String:pointArg]];
        }
        else if(strcmp(argType, "B") == 0){//bool
            int boolArg = lua_toboolean(L, i+2);
            NSNumber *arg = [NSNumber numberWithBool:boolArg];
            [paramsArray addObject:arg];
        }else if(strcmp(argType, "d") == 0){//数字都用double
            double doubleArg = luaL_checknumber(L, i+2);
            NSNumber *arg = [NSNumber numberWithDouble:doubleArg];
            [paramsArray addObject:arg];
        }
    }
    return [paramsArray copy];
}

//支持调用可变参数，最多是10个

static id getArgument(id valObj){
    if (valObj == _nilObj) {
        return nil;
    }
    return valObj;
}

static id (*new_msgSend1)(id, SEL, id,...) = (id (*)(id, SEL, id,...)) objc_msgSend;
static id (*new_msgSend2)(id, SEL, id, id,...) = (id (*)(id, SEL, id, id,...)) objc_msgSend;
static id (*new_msgSend3)(id, SEL, id, id, id,...) = (id (*)(id, SEL, id, id, id,...)) objc_msgSend;
static id (*new_msgSend4)(id, SEL, id, id, id, id,...) = (id (*)(id, SEL, id, id, id, id,...)) objc_msgSend;
static id (*new_msgSend5)(id, SEL, id, id, id, id, id,...) = (id (*)(id, SEL, id, id, id, id, id,...)) objc_msgSend;
static id (*new_msgSend6)(id, SEL, id, id, id, id, id, id,...) = (id (*)(id, SEL, id, id, id, id, id, id,...)) objc_msgSend;
static id (*new_msgSend7)(id, SEL, id, id, id, id, id, id, id,...) = (id (*)(id, SEL, id, id, id, id, id, id,id,...)) objc_msgSend;
static id (*new_msgSend8)(id, SEL, id, id, id, id, id, id, id, id,...) = (id (*)(id, SEL, id, id, id, id, id, id, id, id,...)) objc_msgSend;
static id (*new_msgSend9)(id, SEL, id, id, id, id, id, id, id, id, id,...) = (id (*)(id, SEL, id, id, id, id, id, id, id, id, id, ...)) objc_msgSend;
static id (*new_msgSend10)(id, SEL, id, id, id, id, id, id, id, id, id, id,...) = (id (*)(id, SEL, id, id, id, id, id, id, id, id, id, id,...)) objc_msgSend;

static id invokeVariableParameterMethod(NSMutableArray *origArgumentsList, NSMethodSignature *methodSignature, id sender, SEL selector) {
    
    NSInteger inputArguments = [(NSArray *)origArgumentsList count];
    NSUInteger numberOfArguments = methodSignature.numberOfArguments;
    
    NSMutableArray *argumentsList = [[NSMutableArray alloc] init];
    for (NSUInteger j = 0; j < inputArguments; j++) {
        NSInteger index = MIN(j + 2, numberOfArguments - 1);
        const char *argumentType = [methodSignature getArgumentTypeAtIndex:index];
        id valObj = origArgumentsList[j];
        char argumentTypeChar = argumentType[0] == 'r' ? argumentType[1] : argumentType[0];
        if (argumentTypeChar == '@') {
            [argumentsList addObject:valObj];
        } else {
            return nil;
        }
    }
    
    id results = nil;
    numberOfArguments = numberOfArguments - 2;
    
    //If you want to debug the macro code below, replace it to the expanded code:
    //https://gist.github.com/bang590/ca3720ae1da594252a2e
    #define LP_G_ARG(_idx) getArgument(argumentsList[_idx])
    #define LP_CALL_MSGSEND_ARG1(_num) results = new_msgSend##_num(sender, selector, LP_G_ARG(0));
    #define LP_CALL_MSGSEND_ARG2(_num) results = new_msgSend##_num(sender, selector, LP_G_ARG(0), LP_G_ARG(1));
    #define LP_CALL_MSGSEND_ARG3(_num) results = new_msgSend##_num(sender, selector, LP_G_ARG(0), LP_G_ARG(1), LP_G_ARG(2));
    #define LP_CALL_MSGSEND_ARG4(_num) results = new_msgSend##_num(sender, selector, LP_G_ARG(0), LP_G_ARG(1), LP_G_ARG(2), LP_G_ARG(3));
    #define LP_CALL_MSGSEND_ARG5(_num) results = new_msgSend##_num(sender, selector, LP_G_ARG(0), LP_G_ARG(1), LP_G_ARG(2), LP_G_ARG(3), LP_G_ARG(4));
    #define LP_CALL_MSGSEND_ARG6(_num) results = new_msgSend##_num(sender, selector, LP_G_ARG(0), LP_G_ARG(1), LP_G_ARG(2), LP_G_ARG(3), LP_G_ARG(4), LP_G_ARG(5));
    #define LP_CALL_MSGSEND_ARG7(_num) results = new_msgSend##_num(sender, selector, LP_G_ARG(0), LP_G_ARG(1), LP_G_ARG(2), LP_G_ARG(3), LP_G_ARG(4), LP_G_ARG(5), LP_G_ARG(6));
    #define LP_CALL_MSGSEND_ARG8(_num) results = new_msgSend##_num(sender, selector, LP_G_ARG(0), LP_G_ARG(1), LP_G_ARG(2), LP_G_ARG(3), LP_G_ARG(4), LP_G_ARG(5), LP_G_ARG(6), LP_G_ARG(7));
    #define LP_CALL_MSGSEND_ARG9(_num) results = new_msgSend##_num(sender, selector, LP_G_ARG(0), LP_G_ARG(1), LP_G_ARG(2), LP_G_ARG(3), LP_G_ARG(4), LP_G_ARG(5), LP_G_ARG(6), LP_G_ARG(7), LP_G_ARG(8));
    #define LP_CALL_MSGSEND_ARG10(_num) results = new_msgSend##_num(sender, selector, LP_G_ARG(0), LP_G_ARG(1), LP_G_ARG(2), LP_G_ARG(3), LP_G_ARG(4), LP_G_ARG(5), LP_G_ARG(6), LP_G_ARG(7), LP_G_ARG(8), LP_G_ARG(9));
    #define LP_CALL_MSGSEND_ARG11(_num) results = new_msgSend##_num(sender, selector, LP_G_ARG(0), LP_G_ARG(1), LP_G_ARG(2), LP_G_ARG(3), LP_G_ARG(4), LP_G_ARG(5), LP_G_ARG(6), LP_G_ARG(7), LP_G_ARG(8), LP_G_ARG(9), LP_G_ARG(10));
        
    #define LP_IF_REAL_ARG_COUNT(_num) if([argumentsList count] == _num)

    #define LP_DEAL_MSGSEND(_realArgCount, _defineArgCount) \
        if(numberOfArguments == _defineArgCount) { \
            LP_CALL_MSGSEND_ARG##_realArgCount(_defineArgCount) \
        }
    
    LP_IF_REAL_ARG_COUNT(1) { LP_CALL_MSGSEND_ARG1(1) }
    LP_IF_REAL_ARG_COUNT(2) { LP_DEAL_MSGSEND(2, 1) LP_DEAL_MSGSEND(2, 2) }
    LP_IF_REAL_ARG_COUNT(3) { LP_DEAL_MSGSEND(3, 1) LP_DEAL_MSGSEND(3, 2) LP_DEAL_MSGSEND(3, 3) }
    LP_IF_REAL_ARG_COUNT(4) { LP_DEAL_MSGSEND(4, 1) LP_DEAL_MSGSEND(4, 2) LP_DEAL_MSGSEND(4, 3) LP_DEAL_MSGSEND(4, 4) }
    LP_IF_REAL_ARG_COUNT(5) { LP_DEAL_MSGSEND(5, 1) LP_DEAL_MSGSEND(5, 2) LP_DEAL_MSGSEND(5, 3) LP_DEAL_MSGSEND(5, 4) LP_DEAL_MSGSEND(5, 5) }
    LP_IF_REAL_ARG_COUNT(6) { LP_DEAL_MSGSEND(6, 1) LP_DEAL_MSGSEND(6, 2) LP_DEAL_MSGSEND(6, 3) LP_DEAL_MSGSEND(6, 4) LP_DEAL_MSGSEND(6, 5) LP_DEAL_MSGSEND(6, 6) }
    LP_IF_REAL_ARG_COUNT(7) { LP_DEAL_MSGSEND(7, 1) LP_DEAL_MSGSEND(7, 2) LP_DEAL_MSGSEND(7, 3) LP_DEAL_MSGSEND(7, 4) LP_DEAL_MSGSEND(7, 5) LP_DEAL_MSGSEND(7, 6) LP_DEAL_MSGSEND(7, 7) }
    LP_IF_REAL_ARG_COUNT(8) { LP_DEAL_MSGSEND(8, 1) LP_DEAL_MSGSEND(8, 2) LP_DEAL_MSGSEND(8, 3) LP_DEAL_MSGSEND(8, 4) LP_DEAL_MSGSEND(8, 5) LP_DEAL_MSGSEND(8, 6) LP_DEAL_MSGSEND(8, 7) LP_DEAL_MSGSEND(8, 8) }
    LP_IF_REAL_ARG_COUNT(9) { LP_DEAL_MSGSEND(9, 1) LP_DEAL_MSGSEND(9, 2) LP_DEAL_MSGSEND(9, 3) LP_DEAL_MSGSEND(9, 4) LP_DEAL_MSGSEND(9, 5) LP_DEAL_MSGSEND(9, 6) LP_DEAL_MSGSEND(9, 7) LP_DEAL_MSGSEND(9, 8) LP_DEAL_MSGSEND(9, 9) }
    LP_IF_REAL_ARG_COUNT(10) { LP_DEAL_MSGSEND(10, 1) LP_DEAL_MSGSEND(10, 2) LP_DEAL_MSGSEND(10, 3) LP_DEAL_MSGSEND(10, 4) LP_DEAL_MSGSEND(10, 5) LP_DEAL_MSGSEND(10, 6) LP_DEAL_MSGSEND(10, 7) LP_DEAL_MSGSEND(10, 8) LP_DEAL_MSGSEND(10, 9) LP_DEAL_MSGSEND(10, 10) }
    
    return results;
}

// MARK: - begin lua interface

static int _callC(lua_State *L,BOOL isSuper){
    printLog(@"callC is called isSuper %d",isSuper);
    int argc = lua_gettop(L);
    if(argc<2)
    {//报错，返回一个空值给lua
        printLog(@"callC lack param");
        lua_pushnil(L);
        return 1;
    }
    const char *cClassName = luaL_checkstring(L, 1);
    const char *cSelectorName = luaL_checkstring(L, 2);
    argc = lua_gettop(L);
    NSString *className = [NSString stringWithUTF8String:cClassName];
    NSString *selectorName = [NSString stringWithUTF8String:cSelectorName];
    //查看参数的个数
    printLog(@"callC argc:%d",argc);
    printLog(@"className:%@ selectorName:%@",className,selectorName);
    //参数的协议，前面两个是类名和方法名，第三个参数标识第一个参数的类型，第四个参数是真正的第一个参数，第五个参数是第二个参数类型，第六个参数是真正的第二个参数
    if(argc%2!=0){//不是双数，报错
        printLog(@"callC className:%@ selectorName:%@ param count is no multiple of 2",className,selectorName);
        lua_pushnil(L);
        return 1;
    }
    NSArray *paramsArray = buildCallSelectorParams(L,2);
    id retValue = callSelector(className, selectorName, paramsArray, nil, isSuper);
    //将id返回值直接返回给lua
    if([retValue isKindOfClass:NSNumber.class]){//返回是基本类型
        NSNumber *num = retValue;
        double ret = num.doubleValue;
        printLog(@"callC return double %f",ret);
        lua_pushnumber(L, ret);
    }else if([retValue isKindOfClass:NSString.class]){
        __autoreleasing NSString *str = retValue;
        const char *ret = str.UTF8String;
        printLog(@"callC return string %s",ret);
        lua_pushstring(L, ret);//lua深复制字符串
    }else if([retValue isKindOfClass:[LPBoxing class]]){
        LPBoxing *box = retValue;
        void *point = [box unboxPointer];
        printLog(@"callC return point %p",point);
        lua_pushlightuserdata(L, point);
    }
    else{
        printLog(@"callC return oc object");
        lua_pushlightuserdata(L, (__bridge void *)(retValue));//返回是oc对象
    }
    return 1;
}

static int defineClass(lua_State *L){
    //传递的格式
    //className:superClassName<protocolName1,protocolName2>
    NSString *classDeclaration = [NSString stringWithUTF8String:luaL_checkstring(L, 1)];
    NSString *className;
    NSString *superClassName;
    NSString *protocolNames;
    NSScanner *scanner = [NSScanner scannerWithString:classDeclaration];
    [scanner scanUpToString:@":" intoString:&className];
    if(!scanner.isAtEnd){
        scanner.scanLocation = scanner.scanLocation + 1;
        [scanner scanUpToString:@"<" intoString:&superClassName];
        if(!scanner.isAtEnd){
            scanner.scanLocation = scanner.scanLocation + 1;
            [scanner scanUpToString:@">" intoString:&protocolNames];
        }
    }
    if (!superClassName){
        superClassName = @"NSObject";
    }
    className = trim(className);
    superClassName = trim(superClassName);
    NSArray *protocols = [protocolNames length]?[protocolNames componentsSeparatedByString:@","]:nil;
    defineClassInOC(className,superClassName,protocols);
    return 0;
}

static int callC(lua_State *L){
    return _callC(L,NO);
}

static int _callI(lua_State *L,BOOL isSuper){//第一个参数是实例指针，第二个参数是方法名，后面是
    printLog(@"callI is called isSuper %d",isSuper);
    int argc = lua_gettop(L);
    if(argc<2){
        printLog(@"callI lack param");
        lua_pushnil(L);
        return 1;
    }
    id instance = (__bridge id)(lua_touserdata(L, 1));
    const char *cSelectorName = luaL_checkstring(L, 2);
    NSString *selectorName = [NSString stringWithUTF8String:cSelectorName];
    printLog(@"callI argc:%d",argc);
    printLog(@"selectorName:%@",selectorName);// 这里不能打印instance，不然会报错
    
    if(argc%2!=0){
        printLog(@"callI selectorName:%@ param count is no multiple of 2",selectorName);
        lua_pushnil(L);
        return 1;
    }
    NSArray *paramsArray = buildCallSelectorParams(L,2);
    id retValue = callSelector(nil, selectorName, [paramsArray copy], instance, isSuper);
    if([retValue isKindOfClass:NSNumber.class]){//返回是基本类型
        NSNumber *num = retValue;
        double ret = num.doubleValue;
        printLog(@"callI return double %f",ret);
        lua_pushnumber(L, ret);
    }else if([retValue isKindOfClass:NSString.class]){
        __autoreleasing NSString *str = retValue;
        const char *ret = str.UTF8String;//有可能会空间被释放 坑
        printLog(@"callI return string %s",ret);
        lua_pushstring(L, ret);
    }else if([retValue isKindOfClass:[LPBoxing class]]){
        LPBoxing *box = retValue;
        void *point = [box unboxPointer];
        printLog(@"callC return point %p",point);
        lua_pushlightuserdata(L, point);
    }
    else{
        printLog(@"callI return oc object");
        lua_pushlightuserdata(L, (__bridge void *)(retValue));//返回是指针或者是oc对象
    }
    return 1;
}

static int callI(lua_State *L){
    return _callI(L, NO);
}

static int callSuperI(lua_State *L){
    return _callI(L, YES);
}

//专门为NSString写一个调用函数
static int callNSStringFunc(lua_State *L){
    int argc = lua_gettop(L);
    if(argc<2){
        printLog(@"callNSStringFunc lack param");
        lua_pushnil(L);
        return 1;
    }
    const char *cstr = luaL_checkstring(L, 1);
    const char *cSelectorName = luaL_checkstring(L, 2);
    NSString *selectorName = [NSString stringWithUTF8String:cSelectorName];
    NSString *str = [NSString stringWithUTF8String:cstr];
    printLog(@"callNSStringFunc argc:%d",argc);
    printLog(@"str is %@",str);
    printLog(@"selectorName:%@",selectorName);// 这里不能打印instance，不然会报错
    if(argc%2!=0){
        printLog(@"callNSStringFunc selectorName:%@ param count is no multiple of 2",selectorName);
        lua_pushnil(L);
        return 1;
    }
    NSArray *paramsArray = buildCallSelectorParams(L,2);
    id retValue = callSelector(nil, selectorName, [paramsArray copy], str, NO);
    if([retValue isKindOfClass:NSNumber.class]){//返回是基本类型
        NSNumber *num = retValue;
        double ret = num.doubleValue;
        printLog(@"callI return double %f",ret);
        lua_pushnumber(L, ret);
    }else if([retValue isKindOfClass:NSString.class]){
        __autoreleasing NSString *str = retValue;
        const char *ret = str.UTF8String;//有可能会空间被释放 坑
        printLog(@"callI return string %s",ret);
        lua_pushstring(L, ret);
    }else if([retValue isKindOfClass:[LPBoxing class]]){
        LPBoxing *box = retValue;
        void *point = [box unboxPointer];
        printLog(@"callC return point %p",point);
        lua_pushlightuserdata(L, point);
    }
    else{
        printLog(@"callI return oc object");
        lua_pushlightuserdata(L, (__bridge void *)(retValue));//返回是指针或者是oc对象
    }
    return 1;
}

//调用block的实现，参数是block和函数列表，只支持参数是oc对象，并且有个数限制
static int callBlock(lua_State *L){
    int argc = lua_gettop(L);
    if(argc<1){
        printLog(@"callBlock lack param");
        lua_pushnil(L);
        return 1;
    }
    
    //是偶数参数的话报错
    if(argc%2==0){
        printLog(@"callBlock arg count error");
        lua_pushnil(L);
        return 1;
    }
    NSMutableArray *paramsArray = [[NSMutableArray alloc]init];
    for(int i = 1; i < argc; i += 2){
        const char *argType = luaL_checkstring(L,i+1);
        if(strcmp(argType, "@") == 0){
            id arg = (__bridge id)(lua_touserdata(L, i+2));
            [paramsArray addObject:arg];
        }else if(strcmp(argType, "*") == 0){
            const char *pointArg = luaL_checkstring(L, i+2);
            [paramsArray addObject:[NSString stringWithUTF8String:pointArg]];
        }else if(strcmp(argType, "B") == 0){
            int boolArg = lua_toboolean(L, i+2);
            NSNumber *arg = [NSNumber numberWithBool:boolArg];
            [paramsArray addObject:arg];
        }else if(strcmp(argType, "d") == 0){//数字都用double
            double doubleArg = luaL_checknumber(L, i+2);
            NSNumber *arg = [NSNumber numberWithDouble:doubleArg];
            [paramsArray addObject:arg];
        }
    }
    printLog(@"callBlock with params:%@",paramsArray);

    __autoreleasing id block = (__bridge id)(lua_touserdata(L, 1));
    
    typedef void*(^block0)(void);
    typedef void*(^block1)(id);
    typedef void*(^block2)(id,id);
    typedef void*(^block3)(id,id,id);
    typedef void*(^block4)(id,id,id,id);
    typedef void*(^block5)(id,id,id,id,id);
    typedef void*(^block6)(id,id,id,id,id,id);

    void *ret = nil;
    if(argc == 1){
        block0 b = block;
        ret = b();
    }else if(argc == 3){
        block1 b = block;
        ret = b(paramsArray[0]);
    }else if(argc == 5){
        block2 b = block;
        ret = b(paramsArray[0],paramsArray[1]);
    }else if(argc == 7){
        block3 b = block;
        ret = b(paramsArray[0],paramsArray[1],paramsArray[2]);
    }else if(argc == 9){
        block4 b = block;
        ret = b(paramsArray[0],paramsArray[1],paramsArray[2],paramsArray[3]);
    }else if(argc == 11){
        block5 b = block;
        ret = b(paramsArray[0],paramsArray[1],paramsArray[2],paramsArray[3],paramsArray[4]);
    }else if(argc == 13){
        block6 b = block;
        ret = b(paramsArray[0],paramsArray[1],paramsArray[2],paramsArray[3],paramsArray[4],paramsArray[5]);
    }
    lua_pushlightuserdata(L,ret);
    return 1;
}

static int makeOCStruct(lua_State *L){//用于给lua创建结构体，暂时支持CGRect、CGPoint、CGSize、NSRange
    //第一个参数是需要创建的结构体（CGRect、CGPoint、CGSize、NSRange 其中之一）
    //后面的参数是尺寸参数
    const char *argType = luaL_checkstring(L, 1);
    printLog(@"makeOCStruct with %s",argType);
    if(strcmp(argType, "CGRect") == 0){
        double arg1 = luaL_checknumber(L, 2);
        double arg2 = luaL_checknumber(L, 3);
        double arg3 = luaL_checknumber(L, 4);
        double arg4 = luaL_checknumber(L, 5);
        __autoreleasing id ret = [JSValue valueWithRect:CGRectMake(arg1, arg2, arg3, arg4) inContext:_context];
        lua_pushlightuserdata(L, (__bridge void *)(ret));
        
    }else if(strcmp(argType, "CGPoint") == 0){
        double arg1 = luaL_checknumber(L, 2);
        double arg2 = luaL_checknumber(L, 3);
        __autoreleasing id ret = [JSValue valueWithPoint:CGPointMake(arg1, arg2) inContext:_context];
        lua_pushlightuserdata(L, (__bridge void *)(ret));
        
    }else if(strcmp(argType, "CGSize") == 0){
        double arg1 = luaL_checknumber(L, 2);
        double arg2 = luaL_checknumber(L, 3);
        __autoreleasing id ret = [JSValue valueWithSize:CGSizeMake(arg1, arg2) inContext:_context];
        lua_pushlightuserdata(L, (__bridge void *)(ret));
        
    }else if(strcmp(argType, "NSRange") == 0){
        NSUInteger arg1 = luaL_checknumber(L, 2);
        NSUInteger arg2 = luaL_checknumber(L, 3);
        __autoreleasing id ret = [JSValue valueWithRange:NSMakeRange(arg1, arg2) inContext:_context];
        lua_pushlightuserdata(L, (__bridge void *)(ret));
    }else{
        lua_pushnil(L);
    }
    return 1;
}

static int getNullObject(lua_State *L)
{
    printLog(@"call getNullObject");
    lua_pushlightuserdata(L, (__bridge void *)(_nullObj));
    return 1;
}

static int getNilObject(lua_State *L)
{
    printLog(@"call getNilObject");
    lua_pushlightuserdata(L, (__bridge void *)(_nilObj));
    return 1;
}



//对应jspatch中的overrideMethod
static int redefineClassMethod(lua_State *L){//重定义实例方法，暂时只支持重定义，不支持添加新方法
    //第一个参数是类名
    //第二个参数是方法名
    //第三个参数是lua实现该函数的函数名称
    printLog(@"redefineClassMethod");
    const char *cClassName = luaL_checkstring(L, 1);
    const char *cSelectorName = luaL_checkstring(L, 2);
    const char *cLuaFunctionName = luaL_checkstring(L, 3);
    NSString *selectorName = [NSString stringWithUTF8String:cSelectorName];
    NSString *luaFunctionName = [NSString stringWithUTF8String:cLuaFunctionName];
    
    //假如是重定义class函数的话这里的currCls是MetaClass
    Class currCls = objc_getMetaClass(cClassName);
    
    overrideMethod(currCls, selectorName, luaFunctionName, YES, NULL);
    return 0;
}

static int redefineInstanceMethod(lua_State *L){
    printLog(@"redefineInstanceMethod");
    const char *cClassName = luaL_checkstring(L, 1);
    const char *cSelectorName = luaL_checkstring(L, 2);
    const char *cLuaFunctionName = luaL_checkstring(L, 3);
    NSString *className = [NSString stringWithUTF8String:cClassName];
    NSString *selectorName = [NSString stringWithUTF8String:cSelectorName];
    NSString *luaFunctionName = [NSString stringWithUTF8String:cLuaFunctionName];
    
    //假如是重定义成员函数的话这里的class是instance的class
    Class currCls = NSClassFromString(className);
    
    overrideMethod(currCls, selectorName, luaFunctionName, NO, NULL);
    return 0;
}

//添加类方法
static int addClassMethod(lua_State *L){
    printLog(@"addClassMethod");
    const char *cClassName = luaL_checkstring(L, 1);
    const char *cSelectorName = luaL_checkstring(L, 2);
    const char *cLuaFunctionName = luaL_checkstring(L, 3);
    const char *cTypeDescStr = luaL_checkstring(L, 4);
    NSString *selectorName = [NSString stringWithUTF8String:cSelectorName];
    NSString *luaFunctionName = [NSString stringWithUTF8String:cLuaFunctionName];
    Class currCls = objc_getMetaClass(cClassName);
    overrideMethod(currCls, selectorName, luaFunctionName, YES, cTypeDescStr);
    return 0;
}

static int addInstanceMethod(lua_State *L){
    printLog(@"addInstanceMethod");
    const char *cClassName = luaL_checkstring(L, 1);
    const char *cSelectorName = luaL_checkstring(L, 2);
    const char *cLuaFunctionName = luaL_checkstring(L, 3);
    const char *cTypeDescStr = luaL_checkstring(L, 4);
    NSString *className = [NSString stringWithUTF8String:cClassName];
    NSString *selectorName = [NSString stringWithUTF8String:cSelectorName];
    NSString *luaFunctionName = [NSString stringWithUTF8String:cLuaFunctionName];
    Class currCls = NSClassFromString(className);
    overrideMethod(currCls, selectorName, luaFunctionName, NO, cTypeDescStr);
    return 0;
}

//某些对象不能用反射调用retain（例如lua生成的block），需要用这个来retain这些对象
static int retainObject(lua_State *L){
    printLog(@"retainObject");
    void *p = lua_touserdata(L, 1);
    void *ret = CFBridgingRetain((__bridge id _Nullable)(p));
    lua_pushlightuserdata(L, ret);
    return 1;
}

static int releaseObject(lua_State *L){
    printLog(@"releaseObject");
    void *p = lua_touserdata(L, 1);
    CFBridgingRelease(p);
    return 0;
}

//给lua调用的接口，参数是一个没有参数的lua函数名，和延迟时间
static int dispatchAfter(lua_State *L){
    int argc = lua_gettop(L);
    const char *luaFunctionName = luaL_checkstring(L, 1);
    double time = lua_tonumber(L, 2);
    id argId = _nilObj;
    if(argc == 3){
        argId = (__bridge id)lua_touserdata(L, 3);
    }
    printLog(@"call dispatchAfter luaFunctionName:%s time:%f",luaFunctionName,time);
    NSString *nsLuaFunctionName = [NSString stringWithUTF8String:luaFunctionName];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(time * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        lua_getglobal(L, nsLuaFunctionName.UTF8String);
        lua_pushlightuserdata(L, (__bridge void *)(argId));
        int ret = lua_pcall(L, 1, 0, 0);
        if(ret != 0){
            int t = lua_type(_L, -1);
            if(t == LUA_TSTRING){
                const char *err = lua_tostring(_L, -1);
                printLog(@"lua error in dispatchAfter, error message is %s",err);
                printLog(@"luaFunctionName is %@",nsLuaFunctionName);
            }
            lua_pop(_L, 1);
        }
    });
    return 0;
}

static int dispatchAsyncMain(lua_State *L){
    int argc = lua_gettop(L);
    const char *luaFunctionName = luaL_checkstring(L, 1);
    id argId = _nilObj;
    if(argc == 2){
        argId = (__bridge id)lua_touserdata(L, 2);
    }
    printLog(@"call dispatchAsyncMain luaFunctionName:%s",luaFunctionName);
    NSString *nsLuaFunctionName = [NSString stringWithUTF8String:luaFunctionName];
    dispatch_async(dispatch_get_main_queue(), ^{
        lua_getglobal(L, nsLuaFunctionName.UTF8String);
        lua_pushlightuserdata(L, (__bridge void *)(argId));
        int ret = lua_pcall(L, 1, 0, 0);
        if(ret != 0){
            int t = lua_type(_L, -1);
            if(t == LUA_TSTRING){
                const char *err = lua_tostring(_L, -1);
                printLog(@"lua error in dispatchAsyncMain, error message is %s",err);
                printLog(@"luaFunctionName is %@",nsLuaFunctionName);
            }
            lua_pop(_L, 1);
        }
    });
    return 0;
}

static int dispatchSyncMain(lua_State *L){
    int argc = lua_gettop(L);
    const char *luaFunctionName = luaL_checkstring(L, 1);
    id argId = _nilObj;
    if(argc == 2){
        argId = (__bridge id)lua_touserdata(L, 2);
    }
    printLog(@"call dispatchSyncMain luaFunctionName:%s",luaFunctionName);
    NSString *nsLuaFunctionName = [NSString stringWithUTF8String:luaFunctionName];
    
    void (^runLuaFunc)(void) = ^(void){
        lua_getglobal(L, nsLuaFunctionName.UTF8String);
        lua_pushlightuserdata(L, (__bridge void *)(argId));
        int ret = lua_pcall(L, 1, 0, 0);
        if(ret != 0){
            int t = lua_type(_L, -1);
            if(t == LUA_TSTRING){
                const char *err = lua_tostring(_L, -1);
                printLog(@"lua error in dispatchSyncMain, error message is %s",err);
                printLog(@"luaFunctionName is %@",nsLuaFunctionName);
            }
            lua_pop(_L, 1);
        }
    };

    if ([NSThread currentThread].isMainThread) {
        runLuaFunc();
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            runLuaFunc();
        });
    }
    return 0;
}

//设置oc关联对象（某些对象只能用这个）
static int setObjectProps(lua_State *L){
    id realObj = (__bridge id)lua_touserdata(L, 1);
    NSString *propName = [NSString stringWithUTF8String:luaL_checkstring(L,2)];
    const char *type = luaL_checkstring(L,3);//标记传递的是什么
    if(strcmp(type, "*") == 0){
        //字符串
        const char *value = luaL_checkstring(L, 4);
        objc_setAssociatedObject(realObj, propKey(propName), [NSString stringWithUTF8String:value], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }else if(strcmp(type, "@") == 0){
        //oc对象
        id value = (__bridge id)lua_touserdata(L, 4);
        objc_setAssociatedObject(realObj, propKey(propName), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }else if(strcmp(type, "d")){
        //double 对象
        double value = luaL_checknumber(L, 4);
        objc_setAssociatedObject(realObj, propKey(propName), [NSNumber numberWithDouble:value], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return 0;
}

//获取oc关联对象
static int getObjectProps(lua_State *L){
    id realObj = (__bridge id)lua_touserdata(L, 1);
    NSString *propName = [NSString stringWithUTF8String:luaL_checkstring(L,2)];
    __autoreleasing id value = objc_getAssociatedObject(realObj, propKey(propName));
    if(value == nil){
        lua_pushlightuserdata(L, NULL);
    }
    else if([value isKindOfClass:NSString.class]){
        //之前保存的是字符串
        NSString *str = value;
        lua_pushstring(L, str.UTF8String);
    }else if([value isKindOfClass:NSNumber.class]){
        NSNumber *num = value;
        lua_pushnumber(L, num.doubleValue);
    }else{
        lua_pushlightuserdata(L, (__bridge void *)value);
    }
    return 1;
}

//打印oc对象
static int printObjcObject(lua_State *L){
    id instance = (__bridge id)(lua_touserdata(L, 1));
    NSLog(@"%@",instance);
    return 0;
}

//在printLog中打印lua传递的字符串
static int printLuaString(lua_State *L){
    const char *cstr = luaL_checkstring(L, 1);
    NSLog(@"%@",[NSString stringWithUTF8String:cstr]);
    return 0;
}

//oc对象转字符串返回给lua
static int convertObjectToStr(lua_State *L){
    id instance = (__bridge id)(lua_touserdata(L, 1));
    __autoreleasing NSString *ret = [NSString stringWithFormat:@"%@",instance];
    lua_pushstring(L, ret.UTF8String);//lua必须马上使用这个字符串
    return 1;
}

//转换userdata成str
static int convertUserDataToStr(lua_State *L){
    const char *point = lua_touserdata(L, 1);
    lua_pushstring(L, point);
    return 1;
}

//获取rect对象信息
static int convertCGRectToStr(lua_State *L){
    JSValue *instance = (__bridge id)(lua_touserdata(L, 1));
    CGRect rect = instance.toRect;
    __autoreleasing NSString *ret = [NSString stringWithFormat:@"%f,%f,%f,%f",rect.origin.x,rect.origin.y,rect.size.width,rect.size.height];
    lua_pushstring(L, ret.UTF8String);//lua必须马上使用这个字符串
    return 1;
}

//获取point对象信息
static int convertCGPointToStr(lua_State *L){
    JSValue *instance = (__bridge id)(lua_touserdata(L, 1));
    CGPoint point = instance.toPoint;
    __autoreleasing NSString *ret = [NSString stringWithFormat:@"%f,%f",point.x,point.y];
    lua_pushstring(L, ret.UTF8String);
    return 1;
}

//获取size对象信息
static int convertCGSizeToStr(lua_State *L){
    JSValue *instance = (__bridge id)(lua_touserdata(L, 1));
    CGSize size = instance.toSize;
    __autoreleasing NSString *ret = [NSString stringWithFormat:@"%f,%f",size.width,size.height];
    lua_pushstring(L, ret.UTF8String);
    return 1;
}

//获取range对象信息
static int convertNSRangeToStr(lua_State *L){
    JSValue *instance = (__bridge id)(lua_touserdata(L, 1));
    NSRange range = instance.toRange;
    __autoreleasing NSString *ret = [NSString stringWithFormat:@"%lu,%lu",range.location,range.length];
    lua_pushstring(L, ret.UTF8String);
    return 1;
}

//转换lua的字符串block为真正的block，为传递参数做准备
static int convertLuaBlockToObjcBlock(lua_State *L){
    const char *luaCallbackFuncName = luaL_checkstring(L, 1);
    const char *sign = luaL_checkstring(L, 2);
    __autoreleasing id block = genCallbackBlock(trim([NSString stringWithUTF8String:sign]),trim([NSString stringWithUTF8String:luaCallbackFuncName]));
    lua_pushlightuserdata(L,(__bridge void *)(block));
    return 1;
}

static int luaPatchVersionStr(lua_State *L){
    lua_pushstring(L, versionStr);
    return 1;
}

static int luaPatchVersionNum(lua_State *L){
    lua_pushnumber(L, versionNum);
    return 1;
}


// MARK: - luapatch.core

int luaopen_luapatch_core(lua_State *L){
    _L = L;
    _nilObj = [[NSObject alloc] init];
    _nullObj = [[NSObject alloc] init];
    _context = [[JSContext alloc]init];
    _LPMethodForwardCallLock = [[NSRecursiveLock alloc]init];
    _currInvokeSuperClsName = [NSMutableDictionary new];
    static const luaL_Reg luapatch_lib[] = {
        {"defineClass",defineClass},
        
        {"callC",callC},
        {"callI",callI},
        {"callSuperI",callSuperI},
        {"callNSStringFunc",callNSStringFunc},
        {"callBlock",callBlock},
        
        {"makeOCStruct",makeOCStruct},
        {"getNullObject",getNullObject},
        {"getNilObject",getNilObject},
        
        {"redefineClassMethod",redefineClassMethod},
        {"redefineInstanceMethod",redefineInstanceMethod},
        {"addClassMethod",addClassMethod},
        {"addInstanceMethod",addInstanceMethod},
        
        {"retainObject",retainObject},
        {"releaseObject",releaseObject},
        
        {"dispatchAfter",dispatchAfter},
        {"dispatchAsyncMain",dispatchAsyncMain},
        {"dispatchSyncMain",dispatchSyncMain},
        
        {"setObjectProps",setObjectProps},
        {"getObjectProps",getObjectProps},
        
        {"printObjcObject",printObjcObject},
        {"printLuaString",printLuaString},
        
        {"convertObjectToStr",convertObjectToStr},
        {"convertUserDataToStr",convertUserDataToStr},
        {"convertCGRectToStr",convertCGRectToStr},
        {"convertCGPointToStr",convertCGPointToStr},
        {"convertCGSizeToStr",convertCGSizeToStr},
        {"convertNSRangeToStr",convertNSRangeToStr},
        {"convertLuaBlockToObjcBlock",convertLuaBlockToObjcBlock},
        
        {"luaPatchVersionStr",luaPatchVersionStr},
        {"luaPatchVersionNum",luaPatchVersionNum},
        
        {"setPrintLog",setPrintLog}
    };
    luaL_newlib(_L, luapatch_lib);

    return 1;
}


# luapatch外部接入文档

## 接入方法
1. 把LPEngine.m、LPEngine.h和luapatch.lua拖入对应的工程
2. 添加lua的c语言源码（当前lua版本是5.3.5，不同的lua可能接口不一样，需要根据实际情况手动修改）

## 初始化
具体的初始化方法可以参考demo
1. 先初始化一个lua虚拟机
2. 调用setLuaPath设置lua的环境变量package.path（具体实现参考demo），使lua能够找到luapatch.lua所在的地方，例如  
`setLuaPath(L,[[[NSBundle mainBundle] bundlePath] stringByAppendingString:@"/?.lua"].UTF8String);`
3. 使用以下代码在lua中注册 luapatch.core
```
int top = lua_gettop(L);
luaL_getsubtable(L, LUA_REGISTRYINDEX, LUA_PRELOAD_TABLE);
lua_pushcfunction(L, luaopen_luapatch_core);
lua_setfield(L, top+1, "luapatch.core");
lua_pop(L, 1);
```
4. 使用luaL_dofile启动入口的lua文件

## 使用
在lua中需要使用luapatch模块的话，输入以下代码  
`local luapatch = require("luapatch")`  
以下是luapatch的方法列表  

defineClass  

packPoint  
unpackPoint  
packClass  
unpackClass  

redefineInstanceMethod  
redefineClassMethod  
addInstanceMethod  
addClassMethod  

callNSStringFunc  
callBlock  

makeOCStruct  
getNullObject  
getNilObject  

setObjectProps  
getObjectProps  

printObjcObject  
printLuaString  

convertObjectToStr  
convertUserDataToStr  
convertCGRectToStr  
convertCGPointToStr  
convertCGSizeToStr  
convertNSRangeToStr  
convertLuaBlockToObjcBlock  

dispatchAfter  
dispatchAsyncMain  
dispatchSyncMain  

isPointEqual  

luaPatchVersionStr  
luaPatchVersionNum  

setPrintLog  

假如需要在某个lua文件或者函数中使用packClass，可以这样写  
`local packClass = luapatch.packClass`

## defineClass
用于添加类的函数，传参格式为  
`className:superClassName<protocolName1,protocolName2>`  
具体用法  
`luapatch.defineClass("ViewController:UIViewController<protocol1,protocol2>")`  
这里的ViewController是要声明的类，UIViewController是父类，protocol1和protocol2是协议，假如单纯要定义一个继承自NSObject的类，可以这样写  
`luapatch.defineClass("MyClass")`

## packPoint和unpackPoint
这两个函数是相互相反的函数，packPoint是把oc传过来的userdata转换为table的函数，unpackPoint是把上面的table还原成userdata的函数。  
主要是为了能够使用面向对象的形式进行编程而存在的函数，
生成的table对象可以直接调用方法，例如
obj1.retain()
不过这两个函数一般会在luapatch.lua中调用进行处理，用户一般不会用到

## packClass和unpackClass
和packPoint、unpackPoint差不多，不同的是生成的table是可以用于调用类方法，例如
```
local NSDictionary = packClass("NSDictionary")
local ret = NSDictionary.alloc().init()
```

## redefineInstanceMethod和redefineClassMethod
使用lua实现的函数覆盖oc实现的函数，例如  
`luapatch.redefineInstanceMethod("TestCallORIG","funcInstance","TestCallORIG_funcInstance")`  
第一参数是要替换实现的类，第二个参数是方法的名字，第三个参数是lua中替代的全局函数的名字。  
redefineInstanceMethod和redefineClassMethod的区别在于一个是替换实例函数的实现，一个是替换类函数的实现。

回调函数的第一个参数是实例或者是类名，之后的参数才是调用者传递的参数，例如  
`function TestCallORIG_funcInstance(instance)`  
### lua函数的命名规范
建议lua的全局函数使用TestCallORIG_funcInstance这样的命名方式，开始时类名，之后是函数名，类名和函数名各段使用下划线分割。

## addInstanceMethod和addClassMethod
oc不存在对应的函数的时候，使用这个给oc类或者是实例添加函数，例如  
`luapatch.addInstanceMethod("ViewController","buttonTouch:","ViewController_buttonTouch","void_id")`  
第一个参数是添加函数的类名，第二个参数是要添加的函数名，第三个参数是lua全局函数的名字，第四个参数是添加的方法的签名。  
### 方法签名
上面的函数签名是`void_id`，
意思是返回void，并且接受一个id类型的参数
关于类型和对应的签名可以查看苹果的文档。  
[Type Encodings](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html#//apple_ref/doc/uid/TP40008048-CH100-SW1)

## makeOCStruct
返回一个oc用到的结构体，有四种结构，分别是  
CGRect  
CGPoint  
CGSize  
NSRange  

例如
```
makeOCStruct("CGRect",1,2,3,4)
makeOCStruct("CGPoint",1,2)
makeOCStruct("CGSize",1,2)
makeOCStruct("NSRange",1,2)
```
分别对应CGRectMake、CGPointMake、CGSizeMake、NSMakeRange函数。

## getNullObject
返回一个代表`[NSNull null]`的oc指针。
在调用oc某些函数的时候可能会需要这个值。

## getNilObject
返回一个代表nil的oc指针。
并且可以通过luapatch.isPointEqual比较两个指针是否相等。

## setObjectProps和getObjectProps
setObjectProps给某个对象设置属性，getObjectProps获取之前设置的属性
对象可以是任意的oc对象，例如
`setObjectProps(instance,"key","test str")`
getObjectProps返回对象对应的属性，例如
`getObjectProps(instance,"key")`

## printObjcObject和printLuaString
在oc中利用NSLog输出id对象或者是lua的字符串。

## convertObjectToStr和convertUserDataToStr
转换oc对象成为lua字符串和转换lua中的userdata为lua字符串。
convertUserDataToStr存在的原因是luapatch不能分辨字符串指针和其它指针。
假如传入的是字符串指针的话lua接收到的仍然是指针，所以可以用这个函数把指针转换为字符串。

## convertCGRectToStr、convertCGPointToStr、convertCGSizeToStr和convertNSRangeToStr
把oc结构体转化为lua的字符串，用于查看oc结构体的内容  
返回的字符串如
"1.000000,2.000000,3.000000,4.000000"。
数字顺序是调用make函数初始化的顺序

## convertLuaBlockToObjcBlock
这个函数可以把lua的block转化为oc的block，例如
```
local callbackBlock = convertLuaBlockToObjcBlock('Http_postRequestSessionJsonCallback','void_id_id_id')
```
返回值是oc的block对象  
第一个参数是lua回调函数的名字  
第二个参数是签名
lua的回调函数第一个接收到的是block的实例，之后才是调用者调用的参数，例如  
`function Http_postRequestSessionJsonCallback(instance,data,response,e)`  
假如需要使用面向对象的方式调用返回值的函数，里面的参数都要手动调用packPoint，例如  
```
instance = packPoint(instance)
data = packPoint(data)
response = packPoint(response)
e = packPoint(e)
```

## dispatchAfter、dispatchAsyncMain和dispatchSyncMain
添加lua函数调用到oc的队列中
dispatchAfter接受两个参数，第一个参数是lua全局函数名，第二个参数是要延时的秒数，最后一个参数是可选参数，可以传递一个oc对象（假如要传递多个oc对象需要用NSMutableArray）
例如
```
local arg1 = NSMutableArray.alloc().init()
arg1.addObject("value1")
arg1.addObject("value2")
luapatch.dispatchAfter("ViewController_dispatchAfter1",5,arg1)

function ViewController_dispatchAfter1(argument)
    local value1 = argument.objectAtIndex(0)
    local value2 = argument.objectAtIndex(1)
end
```

dispatchAsyncMain是异步主线程调用函数，参数是lua全局函数名，例如
```
local arg1 = NSMutableArray.alloc().init()
arg1.addObject("value1")
arg1.addObject("value2")
luapatch.dispatchAsyncMain("ViewController_dispatchAsyncMain1",arg1)

function ViewController_dispatchAsyncMain1(argument)
    local value1 = argument.objectAtIndex(0)
    local value2 = argument.objectAtIndex(1)
end
```

dispatchSyncMain是同步主线程调用函数，参数是lua全局函数名，例如
```
local arg1 = NSMutableArray.alloc().init()
arg1.addObject("value1")
arg1.addObject("value2")
luapatch.dispatchSyncMain("ViewController_dispatchSyncMain1",arg1)

function ViewController_dispatchSyncMain1(argument)
    local value1 = argument.objectAtIndex(0)
    local value2 = argument.objectAtIndex(1)
end
```

## callNSStringFunc
可以调用NSString的函数（正常情况下所有NSString都会在lua中以lua字符串的形式存在，因此需要这个函数）
例如
```
local NSUTF8StringEncoding = 4
callNSStringFunc(body,'dataUsingEncoding:',NSUTF8StringEncoding) --转换body字符串为NSData
```

## callBlock
可以调用oc的block，只支持参数全部都是id类型并且数量少于6个，返回一个指针（id），假如这个block本身的返回值是void，那么返回的指针无意义

## retain和release
建议直接使用反射对对象调用retain和release，例如
```
obj1.retain()
obj1.release()
```
对于block对象，直接调用retain可能会出错，推荐使用retainObject和releaseObject

## super
使用super可以调用父类的实例函数，例如

`instance.super().init()`

不过super只能针对某个对象调用其父类的函数，建议只有在需要调用oc实现的super才使用这个函数。

有坑，假如使用不当，可能导致无限循环直到溢出或者是崩溃

## isPointEqual
对比两个对象的指针是否相等，例如
`isPointEqual(objectA,luapatch.getNilObject())`

## luaPatchVersionStr
返回oc端的luaPatch版本字符串

## luaPatchVersionNum
返回oc端的luaPatch版本数字

## setPrintLog
设置是否打luapatch的log方便查问题，默认不打log

## lua传递参数给oc
1. oc需要的是基本类型的话，lua需要传数字
2. oc需要的是SEL，lua需要传字符串
3. oc需要的是NSString对象，lua需要传lua字符串，之后在oc层会自动转化这个对象变成NSString对象
4. oc需要的是NSNumber对象，lua需要传数字，或者是布尔值
5. oc需要的是普通的oc对象（NSObject，NSBlock），lua直接传指针
6. oc需要的是结构体，lua需要传jsvalue的指针
7. oc需要的是class对象，lua传class对象（xxx.class()）
8. oc需要的是字符串char*，lua需要传字符串
9.  oc需要的是普通的c指针，lua需要传指针或者是lua字符串

## oc返回值给lua
1. oc返回值是oc对象的时候，返回指针给lua
2. oc返回值是基本类型（int double bool），lua接收到的返回值也是基本类型（number）
3. oc返回值是NSNumber，lua接收到的还是基本类型（number）
4. oc返回值是NSString，lua接收的的是字符串
5. oc返回值是struct结构体，lua接收到的是指向jsvalue的指针
6. oc返回值是个指针，lua收到的也是指针
7. oc返回值是sel的话，lua接收到的是字符串

## oc传参数给lua
1. oc的参数是基本类型（int double bool），lua会接受到数字类型
2. oc的参数是一个oc对象（NSObject，NSBlock），那么会直接传递指针给lua（NSNumber和NSString是特例）
3. oc的参数是一个struct结构体，那么会添加到一个js的context中，并且作为一个JSValue指针传递给lua
4. oc的参数是一个SEL，会传给lua字符串
5. oc的参数是一个指针，直接把该指针传给lua
6. oc的参数是一个class，直接传指针
7. oc的参数是NSNumber类型的参数，lua会直接收到数字类型
8. oc的参数是NSString类型的参数，lua接收到字符串

## lua返回值给oc
1. 返回oc对象、指针，这些都是原样返回给oc指针，不作处理（假如返回值是NSNumber，需要给一个接口让lua能够根据数字和字符串生成NSNumber和NSString的指针）
2. 返回struct结构体，对lua返回的指针调用toRect之类的，获取之前保存的结构体
3. 返回基本类型，lua返回一个lua的数字，oc根据方法具体需要的返回值设置成具体的值
4. 假如oc需要一个NSString，lua可以返回一个字符串，oc会自动兼容处理
5. 假如oc需要一个NSNumber，lua可以返回一个数字，oc会自动兼容处理
6. 假如oc需要SEL，lua要传一个字符串给oc，oc把字符串转换为SEL

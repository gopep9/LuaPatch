
local luapatch_core = require("luapatch.core")

local luapatch = {}

-- luapatch_log_switch 开关，默认关闭不打印log
local luapatch_log_switch = false

local function setPrintLog(state)
	-- body
	luapatch_log_switch = state
	luapatch_core.setPrintLog(state)
end

local function printLog(str)
    -- body
    if luapatch_log_switch then
        print(str)
    end
end

printLog("加载LuaPatch.lua成功")

--定义基类，让所有的类都有setProp:forKey:和getProp:方法
luapatch_core.defineClass('NSObject')


local function tableToStr(t)
    -- body
    local retStr = ''
    local tableToStr_cache={}
    local function sub_tableToStr(t,indent)
        if (tableToStr_cache[tostring(t)]) then
            retStr = retStr..indent.."*"..tostring(t)..'\n'
        else
            tableToStr_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        retStr = retStr..indent.."["..pos.."] => "..tostring(val).." {"..'\n'
                        sub_tableToStr(val,indent..string.rep(" ",string.len(pos)+8))
                        retStr = retStr..indent..string.rep(" ",string.len(pos)+6).."}"..'\n'
                    elseif (type(val)=="string") then
                        retStr = retStr..indent.."["..pos..'] => "'..val..'"'..'\n'
                    else
                        retStr = retStr..indent.."["..pos.."] => "..tostring(val)..'\n'
                    end
                end
            else
                retStr = retStr..indent..tostring(t)..'\n'
            end
        end
    end
    if (type(t)=="table") then
        retStr = retStr..tostring(t).." {"..'\n'
        sub_tableToStr(t,"  ")
        retStr = retStr.."}"..'\n'
    else
        sub_tableToStr(t,"  ")
    end
    return retStr
end

local function charAppearCount(str,c)
    local count = 0
    local i = 1
    for i = 1,#str do
        if string.sub(str,i,i) == c then
            count = count + 1
        end
    end
    return count
end

local nilObject = luapatch_core.getNilObject()
local nullObject = luapatch_core.getNullObject()

local function buildArgList(...)
    local arglist = {}
    for _, v in ipairs{...} do
        if type(v) == "boolean" then
            arglist[#arglist + 1] = "B"
            arglist[#arglist + 1] = v
        elseif type(v) == "number" then
            arglist[#arglist + 1] = "d"
            arglist[#arglist + 1] = v
        elseif type(v) == "string" then
            arglist[#arglist + 1] = "*"
            arglist[#arglist + 1] = v
        elseif type(v) == "userdata" then
            arglist[#arglist + 1] = "@"
            arglist[#arglist + 1] = v
        elseif type(v) == "table" then --被table封装过的指针对象，在这里还原
            arglist[#arglist + 1] = "@"
            arglist[#arglist + 1] = v.point
        end
    end
    return arglist
end

local instanceObject = { point = nilObject}
function instanceObject:new(o)
    o = o or {}
    setmetatable(o,self)--设置instanceObject对象为生成对象o的元表
    self.__index = function ( self, key )--设置全局instanceObject对象的__index是一个函数
        --假如键是super，返回一个函数，调用这个函数生成isSuper为true的对象
        if key == "super" then
            return function ( ... )
                return instanceObject:new({point = self.point ,isSuper = true})
            end
        end
        return function ( ... )
            local method = string.gsub(key,"_",":")
            method = string.gsub(method,"::","_")
            if #{...} > charAppearCount(method,":") then
                method = method..":"
            end
            --假如是调用super的情况
            local arglist = buildArgList(...)
            printLog("call callI in instanceObject instance:",self.point,"method",method)
            printLog("arglist")
            printLog(tableToStr(arglist))
            local ret = nil
            if self.isSuper == true then
                ret = luapatch_core.callSuperI(self.point,method,table.unpack(arglist))
            else
                ret = luapatch_core.callI(self.point,method,table.unpack(arglist))
            end
            if type(ret) == "userdata" then
                return instanceObject:new({point = ret})
            end
            return ret
        end
    end
    return o
end

local classObject = { className = "NSObject" }
function classObject:new(o)
    o = o or {}
    setmetatable(o,self)
    self.__index = function (self, key) --这里后面的self和前面的self是不一样的
        return function(...)
            local method = string.gsub(key,"_",":") -- 用冒号替换_，还原真实的函数名称，这里规定假如有两个__相连的表示真实的_符
            method = string.gsub(method,"::","_")
            --假如参数个数比:号多的话，要在最后添加:号
            if #{...} > charAppearCount(method,":") then
                method = method..":"
            end
            --遍历参数
            local arglist = buildArgList(...)
            printLog("call callC in classObject className:"..self.className.." method:"..method)
            printLog("arglist")
            printLog(tableToStr(arglist))
            local ret = luapatch_core.callC(self.className,method,table.unpack(arglist))
            if type(ret) == "userdata" then
                return instanceObject:new({point = ret})
            end
            return ret
        end
    end
    return o
end

local function packPoint( p )
    if type(p) == "userdata" then
        return instanceObject:new({point = p})
    end
    return p
end

local function unpackPoint( t )
    if type(t) == "table" then
        return t.point
    end
    return t
end

local function packClass( className )
    if type(className) == "string" then
        return classObject:new{className = className}
    end
    return className
end

local function unpackClass( class )
    if type(class) == "table" then
        return class.className
    end
    return class
end

--这里必须要污染全局命名空间，不然oc回调不回来
local function redefineInstanceMethod(className,ocMethod,luaCallbackFuncName)
    -- body
    local realCallbackFunc = luaCallbackFuncName.."_LuaPretreatmentFunc"
    local execStr = realCallbackFunc..[=[ = 
    function(...) 
        local arglist = {}
        for _, v in ipairs{...} do
            arglist[#arglist + 1] = require("luapatch").packPoint(v)
        end return require("luapatch").unpackPoint(
        ]=]..luaCallbackFuncName.."(table.unpack(arglist))) end"
    load(execStr)()
    luapatch_core.redefineInstanceMethod(className,ocMethod,realCallbackFunc)
end

local function redefineClassMethod(className,ocMethod,luaCallbackFuncName)
    -- body
    local realCallbackFunc = luaCallbackFuncName.."_LuaPretreatmentFunc"
    local execStr = realCallbackFunc..[=[ = 
    function(...) 
        local arglist = {}
        for _, v in ipairs{...} do
            arglist[#arglist + 1] = require("luapatch").packPoint(v)
        end return require("luapatch").unpackPoint(
        ]=]..luaCallbackFuncName.."(table.unpack(arglist))) end"
    load(execStr)()
    luapatch_core.redefineClassMethod(className,ocMethod,realCallbackFunc)    
end


local function addInstanceMethod(className,ocMethod,luaCallbackFuncName,TypeDescStr)
    -- body
    local realCallbackFunc = luaCallbackFuncName.."_LuaPretreatmentFunc"
    local execStr = realCallbackFunc..[=[ =
    function( ... )
        local arglist = {}
        for _, v in ipairs{...} do
            arglist[#arglist + 1] = require("luapatch").packPoint(v)
        end return require("luapatch").unpackPoint(
        ]=]..luaCallbackFuncName.."(table.unpack(arglist))) end"
    load(execStr)()
    luapatch_core.addInstanceMethod(className,ocMethod,realCallbackFunc,TypeDescStr)
end

local function addClassMethod(className,ocMethod,luaCallbackFuncName,TypeDescStr)
    -- body
    local realCallbackFunc = luaCallbackFuncName.."_LuaPretreatmentFunc"
    local execStr = realCallbackFunc..[=[ =
    function( ... )
        local arglist = {}
        for _, v in ipairs{...} do
            arglist[#arglist + 1] = require("luapatch").packPoint(v)
        end return require("luapatch").unpackPoint(
        ]=]..luaCallbackFuncName.."(table.unpack(arglist))) end"
    load(execStr)()
    luapatch_core.addClassMethod(className,ocMethod,realCallbackFunc,TypeDescStr)
end


local function dispatchAfter(luaCallbackFuncName,second,argument)
    -- body
    local realCallbackFunc = luaCallbackFuncName.."_LuaPretreatmentFunc"
    local execStr = realCallbackFunc..[=[ =
    function( ... )
        local arglist = {}
        for _, v in ipairs{...} do
            arglist[#arglist + 1] = require("luapatch").packPoint(v)
        end 
        ]=]..luaCallbackFuncName.."(table.unpack(arglist)) end"
    load(execStr)()
    if argument == nil then
        argument = nilObject
    end
    argument = unpackPoint(argument)
    luapatch_core.dispatchAfter(realCallbackFunc,second,argument)
end

local function dispatchAsyncMain(luaCallbackFuncName,argument)
    -- body
    local realCallbackFunc = luaCallbackFuncName.."_LuaPretreatmentFunc"
    local execStr = realCallbackFunc..[=[ =
    function( ... )
        local arglist = {}
        for _, v in ipairs{...} do
            arglist[#arglist + 1] = require("luapatch").packPoint(v)
        end 
        ]=]..luaCallbackFuncName.."(table.unpack(arglist)) end"
    load(execStr)()
    if argument == nil then
        argument = nilObject
    end
    argument = unpackPoint(argument)
    luapatch_core.dispatchAsyncMain(realCallbackFunc,argument)
end

local function dispatchSyncMain(luaCallbackFuncName,argument)
    -- body
    local realCallbackFunc = luaCallbackFuncName.."_LuaPretreatmentFunc"
    local execStr = realCallbackFunc..[=[ =
    function( ... )
        local arglist = {}
        for _, v in ipairs{...} do
            arglist[#arglist + 1] = require("luapatch").packPoint(v)
        end 
        ]=]..luaCallbackFuncName.."(table.unpack(arglist)) end"
    load(execStr)()
    if argument == nil then
        argument = nilObject
    end
    argument = unpackPoint(argument)
    luapatch_core.dispatchSyncMain(realCallbackFunc,argument)
end

--调用nsstring的函数
local function callNSStringFunc( ... )
    -- body
    local params = {}
    local instance = ''
    local method = ''
    for k,v in ipairs{...} do
        if k == 1 then
            instance = v
        elseif k == 2 then
            method = v
        else
            params[#params + 1] = v
        end
    end
    local arglist = buildArgList(table.unpack(params))
    printLog("call callNSStringFunc str:"..instance.." method:"..method)
    printLog("arglist")
    printLog(tableToStr(arglist))
    local ret = luapatch_core.callNSStringFunc(instance,method,table.unpack(arglist))
    if type(ret) == "userdata" then
        return instanceObject:new({point = ret})
    end
    return ret
end

local function callBlock( ... )
    -- body
    local params = {}
    local block = ''
    for k,v in ipairs{...} do
        if k == 1 then
            block = v
        else
            params[#params + 1] = v
        end
    end
    local arglist = buildArgList(table.unpack(params))
    printLog("call callBlock with arglist")
    printLog(tableToStr(arglist))
    local ret = luapatch_core.callBlock(unpackPoint(block),table.unpack(arglist))
    if type(ret) == "userdata" then
        return instanceObject:new({point = ret})
    end
    return ret
end

--封装makeOCStruct的返回值为table
local function  makeOCStruct( ... )
    -- body
    return packPoint(luapatch_core.makeOCStruct(...))
end

local function getNullObject( ... )
    -- body
    return packPoint(nullObject)
end

local function getNilObject( ... )
    -- body
    return packPoint(nilObject)
end

local function retainObject(t)
    -- body
    return luapatch_core.retainObject(unpackPoint(t))
end

local function releaseObject(t)
    -- body
    luapatch_core.releaseObject(unpackPoint(t))
end

local function setObjectProps(obj,key,value)
    -- body
    local t = ''
    if type(value) == "number" then
        t = 'd'
    elseif type(value) == "string" then
        t = '*'
    elseif type(value) == "userdata" or type(value) == "table" then
        t = '@'
    end
    luapatch_core.setObjectProps(unpackPoint(obj),key,t,unpackPoint(value))
end

local function getObjectProps(obj,key)
    -- body
    return packPoint(luapatch_core.getObjectProps(unpackPoint(obj),key))
end

local function printObjcObject(t)
    -- body
    luapatch_core.printObjcObject(unpackPoint(t))
end

local function convertObjectToStr(t)
    -- body
    return luapatch_core.convertObjectToStr(unpackPoint(t))
end

local function convertUserDataToStr(t)
    -- body
    return luapatch_core.convertUserDataToStr(unpackPoint(t))
end

local function convertCGRectToStr(t)
    -- body
    return luapatch_core.convertCGRectToStr(unpackPoint(t))
end

local function convertCGPointToStr(t)
    -- body
    return luapatch_core.convertCGPointToStr(unpackPoint(t))
end

local function convertCGSizeToStr(t)
    -- body
    return luapatch_core.convertCGSizeToStr(unpackPoint(t))
end

local function convertNSRangeToStr(t)
    -- body
    return luapatch_core.convertNSRangeToStr(unpackPoint(t))
end

local function convertLuaBlockToObjcBlock(luaCallbackFuncName,TypeDescStr)
    -- body
    local realCallbackFunc = luaCallbackFuncName.."_LuaPretreatmentFunc"
    local execStr = realCallbackFunc..[=[ = 
    function(...) 
        local arglist = {}
        for _, v in ipairs{...} do
            arglist[#arglist + 1] = require("luapatch").packPoint(v)
        end return require("luapatch").unpackPoint(
        ]=]..luaCallbackFuncName.."(table.unpack(arglist))) end"
    load(execStr)()
    return packPoint(luapatch_core.convertLuaBlockToObjcBlock(realCallbackFunc,TypeDescStr))
end

local function isPointEqual(table1,table2)
    -- body
    return unpackPoint(table1) == unpackPoint(table2)
end

luapatch.tableToStr = tableToStr

luapatch.defineClass = luapatch_core.defineClass

luapatch.packPoint = packPoint
luapatch.unpackPoint = unpackPoint
luapatch.packClass = packClass
luapatch.unpackClass = unpackClass

luapatch.redefineInstanceMethod = redefineInstanceMethod
luapatch.redefineClassMethod = redefineClassMethod
luapatch.addInstanceMethod = addInstanceMethod
luapatch.addClassMethod = addClassMethod

luapatch.callNSStringFunc = callNSStringFunc
luapatch.callBlock = callBlock

luapatch.makeOCStruct = makeOCStruct
luapatch.getNullObject = getNullObject
luapatch.getNilObject = getNilObject

luapatch.retainObject = retainObject
luapatch.releaseObject = releaseObject

luapatch.setObjectProps = setObjectProps
luapatch.getObjectProps = getObjectProps

luapatch.printObjcObject = printObjcObject
luapatch.printLuaString = luapatch_core.printLuaString

luapatch.convertObjectToStr = convertObjectToStr
luapatch.convertUserDataToStr = convertUserDataToStr
luapatch.convertCGRectToStr = convertCGRectToStr
luapatch.convertCGPointToStr = convertCGPointToStr
luapatch.convertCGSizeToStr = convertCGSizeToStr
luapatch.convertNSRangeToStr = convertNSRangeToStr
luapatch.convertLuaBlockToObjcBlock = convertLuaBlockToObjcBlock

luapatch.dispatchAfter = dispatchAfter
luapatch.dispatchAsyncMain = dispatchAsyncMain
luapatch.dispatchSyncMain = dispatchSyncMain

luapatch.classObject = classObject

luapatch.isPointEqual = isPointEqual

luapatch.luaPatchVersionStr = luapatch_core.luaPatchVersionStr
luapatch.luaPatchVersionNum = luapatch_core.luaPatchVersionNum

luapatch.setPrintLog = setPrintLog

return luapatch

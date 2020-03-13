--测试lua接收到的oc传入的参数


local crash = function (message)
	-- body
	print("program crash")
	print(message)
	os.exit(1)
end
--这里的assert好像不能检测错误
_G.TestForwardArgument_checkInt = function (className,i)
	-- body
	-- assert(i == 1,"TestForwardArgument_checkInt error")
	if i ~= 1 then
		crash("TestForwardArgument_checkInt error")
	end
	return i
end

_G.TestForwardArgument_checkDouble = function (className,i)
	-- body
	-- assert(i == 1.1,"TestForwardArgument_checkDouble error")
	if i ~= 1.1 then
		crash("TestForwardArgument_checkDouble error")
	end
	return i
end
_G.TestForwardArgument_checkId = function (className,i)
	-- body
	-- assert(i.isKindOfClass(require("luapatch").packClass("NSDictionary").class()) == 1,"TestForwardArgument_checkId error")
	if i.isKindOfClass(require("luapatch").packClass("NSDictionary").class()) ~= 1 then
		crash("TestForwardArgument_checkId error")
	end
	return i
end
_G.TestForwardArgument_checkSEL = function (className,i)
	-- body
	-- assert(i == "checkSEL:","TestForwardArgument_checkSEL error")
	print("call TestForwardArgument_checkSEL in lua")
	if i ~= "checkSEL:" then
		crash("TestForwardArgument_checkSEL error")
	end
	return i
end
_G.TestForwardArgument_checkPoint = function (className,i)
	-- body
	-- assert(require("luapatch").convertUserDataToStr(i) == "hello world","TestForwardArgument_checkPoint error")
	if require("luapatch").convertUserDataToStr(i) ~= "hello world" then
		crash("TestForwardArgument_checkPoint error")
	end
	return i
end
_G.TestForwardArgument_checkClass = function (className,i)
	-- body
	local luapatch = require("luapatch")
	-- assert(luapatch.unpackPoint(i) == luapatch.unpackPoint(luapatch.packClass("NSDictionary").class()),"TestForwardArgument_checkClass error")
	if luapatch.unpackPoint(i) ~= luapatch.unpackPoint(luapatch.packClass("NSDictionary").class()) then
		crash("TestForwardArgument_checkClass error")
	end
	return i
end
_G.TestForwardArgument_checkNum = function (className,i)
	-- body
	-- assert(i == 1,"TestForwardArgument_checkNum error")
	if i ~= 1 then
		crash("TestForwardArgument_checkNum error")
	end
	return i
end
_G.TestForwardArgument_checkStr = function (className,i)
	-- body
	-- assert(i == "hello world","TestForwardArgument_checkStr error")
	if i ~= "hello world" then
		crash("TestForwardArgument_checkStr error")
	end
	return i
end


-- expose("expose lua function")

describe("test forward argument",function( ... )
	-- body
	local luapatch = require("luapatch")
	it("start test forward argument",function ( ... )
		-- body
		luapatch.redefineClassMethod("TestForwardArgument","checkInt:","TestForwardArgument_checkInt")
		luapatch.redefineClassMethod("TestForwardArgument","checkDouble:","TestForwardArgument_checkDouble")
		luapatch.redefineClassMethod("TestForwardArgument","checkId:","TestForwardArgument_checkId")
		luapatch.redefineClassMethod("TestForwardArgument","checkSEL:","TestForwardArgument_checkSEL")
		luapatch.redefineClassMethod("TestForwardArgument","checkPoint:","TestForwardArgument_checkPoint")
		luapatch.redefineClassMethod("TestForwardArgument","checkClass:","TestForwardArgument_checkClass")
		luapatch.redefineClassMethod("TestForwardArgument","checkNum:","TestForwardArgument_checkNum")
		luapatch.redefineClassMethod("TestForwardArgument","checkStr:","TestForwardArgument_checkStr")
		local TestForwardArgument = luapatch.packClass("TestForwardArgument")
		TestForwardArgument.startCheckArgument()
	end)
end)

-- 测试是否传值给oc，判断都在oc中进行

_G.TestCallSelectorArgument_block1 = function (instance,i)
	-- body
	print("TestCallSelectorArgument_block1 i")
	print(i)
	return i + 1
end

_G.TestCallSelectorArgument_block2 = function (instance,str)
	-- body
	print("TestCallSelectorArgument_block2 str")
	print(str)
	-- return i + 1
end


describe("test call selector argument",function ( ... )
	-- body
	local luapatch = require("luapatch")
	local packClass = luapatch.packClass
	local TestCallSelectorArgument = packClass("TestCallSelectorArgument")
	local NSDictionary = packClass("NSDictionary")
	it("pass c value to oc",function ( ... )
		-- body
		TestCallSelectorArgument.checkInt(1)
		TestCallSelectorArgument.checkDouble(1.1)
	end)

	it("pass string and num to oc",function ( ... )
		-- body
		TestCallSelectorArgument.checkNSString("hello world")
		TestCallSelectorArgument.checkNSNumber(1)
	end)

	it("pass struct to oc",function ( ... )
		-- body
		-- 在测试结构体的那里已经测试了
	end)

	it("pass id to oc",function ( ... )
		-- body
		TestCallSelectorArgument.checkIsDictionary(NSDictionary.new())
	end)

	it("pass class obj to oc",function ( ... )
		-- body
		TestCallSelectorArgument.checkIsDictionaryClass(NSDictionary.class())
	end)

	it("pass char * to oc",function ( ... )
		-- body
		TestCallSelectorArgument.checkCStr("hello world")
	end)

	it("pass sel to oc",function ( ... )
		-- body
		TestCallSelectorArgument.checkSEL("checkSEL")
	end)

	it("pass block to oc",function ( ... )
		-- body
        local block = luapatch.convertLuaBlockToObjcBlock("TestCallSelectorArgument_block1","int_int")
        TestCallSelectorArgument.checkBlock(block)
        local block2 = luapatch.convertLuaBlockToObjcBlock("TestCallSelectorArgument_block2","void_id")
		TestCallSelectorArgument.checkBlock2(block2)
	end)
end)

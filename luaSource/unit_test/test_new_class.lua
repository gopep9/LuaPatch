_G.Test_new_class_classFunction = function ( ... )
	-- body
	print("call Test_new_class_classFunction")
end

describe("test new class",function ( ... )
	-- body
	local luapatch = require("luapatch")
	
	local packClass = luapatch.packClass
	-- local Test_new_class = packClass("Test_new_class")
	it("create new class",function ( ... )
		-- body
		luapatch.defineClass("Test_new_class")
		local Test_new_class = packClass("Test_new_class")
		luapatch.addClassMethod("Test_new_class","helloworld","Test_new_class_classFunction","void")
		Test_new_class.helloworld()
		--setprop and getprop
		local Test_new_class_instance = Test_new_class.alloc().init()
		Test_new_class_instance.setProp_forKey("value","key")
		assert.equal(Test_new_class_instance.getProp("key"),"value")
	end)
	it("define current exist class",function ( ... )
		-- body
		luapatch.defineClass("TestDefineClass")
		local TestDefineClass = packClass("TestDefineClass")
		local TestDefineClassInstance = TestDefineClass.alloc().init()
		TestDefineClassInstance.setProp_forKey("value","key")
		assert.equal(TestDefineClassInstance.getProp("key"),"value")
	end)
end)
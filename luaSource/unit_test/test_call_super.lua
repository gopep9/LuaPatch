--测试在lua中调用super函数，查看是否能调用对应的super函数
--测试oc实现的父函数和lua实现的父函数
--假如父函数缺失的话是否有办法？

local crash = function (message)
	-- body
	print("program crash")
	print(message)
	os.exit(1)
end

_G.TestBaseClass_funcInstance2 = function (instance)
	-- body
	return 1;
end

_G.TestDerivedClass1_funcInstance2 = function (instance)
	-- body
	return 2;
end

_G.TestBaseClass_funcInstance4 = function (instance)
	-- body
	return 3;
end

_G.TestDerivedClass1_funcInstance4 = function (instance)
	-- body
	--坑，这里不能再调用super了，只能直接调用对应的lua函数，bug，待fix
	-- return instance.super.funcInstance4()
	return TestBaseClass_funcInstance4(instance)
end

_G.TestBaseClass_funcInstance5 = function (instance)
	-- body
	return 1
end

describe("test call super",function ( ... )
	-- body
	local luapatch = require("luapatch")
	local packClass = luapatch.packClass
		local TestBaseClass = packClass("TestBaseClass")
	local TestBaseClassInstance = TestBaseClass.alloc().init()
	local TestDerivedClass1 = packClass("TestDerivedClass1")
	local TestDerivedClass1Instance = TestDerivedClass1.alloc().init()
	local TestDerivedClass2 = packClass("TestDerivedClass2")
	local TestDerivedClass2Instance = TestDerivedClass2.alloc().init()
	it("test call oc implement super",function ( ... )
		-- body
		--调用oc实现的父函数
		assert.equal(TestDerivedClass1Instance.super().funcInstance1(),1)
	end)

	-- it("test call ")
	it("test call lua implement super",function ( ... )
		-- body
		--调用lua实现的父函数
		luapatch.addInstanceMethod("TestBaseClass","funcInstance2","TestBaseClass_funcInstance2","int")
		luapatch.addInstanceMethod("TestDerivedClass1","funcInstance2","TestDerivedClass1_funcInstance2","int")
		assert.equal(TestDerivedClass1Instance.super().funcInstance2(),1)
		assert.equal(TestDerivedClass1Instance.funcInstance2(),2)
		-- TestDerivedClass2Instance.super().
	end)

	it("test call lua implement super and redefine oc function",function ( ... )
		-- body
		luapatch.redefineInstanceMethod("TestBaseClass","funcInstance5","TestBaseClass_funcInstance5")
		assert.equal(TestDerivedClass1Instance.super().funcInstance5(),1)
	end)

	it("test call oc implement grandfather function",function ( ... )
		-- body
		assert.equal(TestDerivedClass2Instance.super().funcInstance3(),1)
	end)

	it("test call lua implement grandfather function",function ( ... )
		-- body
		luapatch.addInstanceMethod("TestBaseClass","funcInstance4","TestBaseClass_funcInstance4","int")
		luapatch.addInstanceMethod("TestDerivedClass1","funcInstance4","TestDerivedClass1_funcInstance4","int")
		assert.equal(TestDerivedClass2Instance.super().funcInstance4(),3)
	end)
end)
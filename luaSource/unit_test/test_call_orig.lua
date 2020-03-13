--测试是否能调用原函数，具体调用的实现暂时写在TestCallORIG

describe("test call oc orig function",function( ... )
	-- body
	local luapatch = require("luapatch")
	local packClass = luapatch.packClass
	local TestCallORIG = packClass("TestCallORIG")
	it("call class orig function",function ( ... )
		-- body
		local funcInstanceRet = TestCallORIG.new().funcInstance()
		assert.equal(funcInstanceRet,2)
		local funcClassRet = TestCallORIG.funcClass()
		assert.equal(funcClassRet,3)
	end)
end)

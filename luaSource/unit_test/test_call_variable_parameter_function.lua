describe("test call variable parameter function",function ( ... )
	-- body
	local luapatch = require("luapatch")
	local packClass = luapatch.packClass
	local TestVariableParameter = packClass("TestVariableParameter")
	it("test 1",function ( ... )
		-- body
		local str = TestVariableParameter.logWithFormat("%@%@%@","a","b",0)
		assert.equal(str,"ab0")
	end)
end)
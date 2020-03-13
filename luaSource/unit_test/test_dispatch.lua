_G.TestdispatchAfter_lua_function = function ( ... )
	-- body
	print("call TestdispatchAfter_lua_function")
end

_G.TestdispatchAsyncMain_lua_function = function ( ... )
	-- body
	print("call TestdispatchAsyncMain_lua_function")
end

_G.TestdispatchSyncMain_lua_function = function ( ... )
	-- body
	print("call TestdispatchSyncMain_lua_function")
end

describe("test dispatch",function ( ... )
	-- body
	local luapatch = require("luapatch")
	it("test dispatchAfter",function ( ... )
		-- body
		luapatch.dispatchAfter("TestdispatchAfter_lua_function",0)
	end)
	it("test ispatchAsyncMain",function ( ... )
		-- body
		luapatch.dispatchAsyncMain("TestdispatchAsyncMain_lua_function")
	end)
	it("test dispatchSyncMain",function ( ... )
		-- body
		luapatch.dispatchSyncMain("TestdispatchSyncMain_lua_function")
	end)
end)


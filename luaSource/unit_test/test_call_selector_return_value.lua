
    
describe("test call selector return value",function ( ... )
	-- body
    local luapatch = require("luapatch")
    local packClass = luapatch.packClass
    local unpackPoint = luapatch.unpackPoint
    local TestCallSelectorReturnValue = packClass("TestCallSelectorReturnValue")
    local NSDictionary = packClass("NSDictionary")
    local NSArray = packClass("NSArray")
	it("void return value", function( ... )
		-- body
        TestCallSelectorReturnValue.returnVoid()
	end)

	it("oc struct return value", function()

        local ret = TestCallSelectorReturnValue.returnCGRect()
        assert.truthy(ret)
        print("CGRect in test makeOCStruct")
        assert.equal(luapatch.convertCGRectToStr(ret),"1.000000,2.000000,3.000000,4.000000")

        local ret = TestCallSelectorReturnValue.returnCGPoint()
        assert.truthy(ret)
        print("CGPoint in test makeOCStruct")
        assert.equal(luapatch.convertCGPointToStr(ret),"1.000000,2.000000")

        local ret = TestCallSelectorReturnValue.returnCGSize()
        assert.truthy(ret)
        print("CGSize in test makeOCStruct")
        assert.equal(luapatch.convertCGSizeToStr(ret),"1.000000,2.000000")

        local ret = TestCallSelectorReturnValue.returnNSRange()
        assert.truthy(ret)
        print("NSRange in test makeOCStruct")
        assert.equal(luapatch.convertNSRangeToStr(ret),"1,2")
    end)

    it("id return value",function ( ... )
    	-- body
        local ret = TestCallSelectorReturnValue.returnDict()
        assert.equal(ret.isKindOfClass(NSDictionary.class()),1)
    end)

    it("c return value",function ( ... )
    	-- body
        local ret = TestCallSelectorReturnValue.returnInt()
        assert.are.equal(ret,1)
        local ret = TestCallSelectorReturnValue.returnDouble()
        assert.are.equal(ret,1.1)
    end)

    it("NSString and NSNumber return value",function ( ... )
        -- body
        local ret = TestCallSelectorReturnValue.returnStr()
        assert.equal(ret,"hello world")
        local ret = TestCallSelectorReturnValue.returnNum()
        assert.equal(ret,1)
    end)

    it("point return value(char*)",function ( ... )
    	-- body
        local ret = TestCallSelectorReturnValue.returnCStr()
        local str = luapatch.convertUserDataToStr(ret)
        print("point return value(char*)")
        print(unpackPoint(ret))
        print(str)
        assert.equal(str,"hello world")
    end)

    it("class object return value",function ( ... )
    	-- body
        local ret = TestCallSelectorReturnValue.returnCls()
        local NSDictionary_class = NSDictionary.class()
        assert.equal(luapatch.unpackPoint(ret),luapatch.unpackPoint(NSDictionary_class))
    end)

    it("select object return value",function ( ... )
    	-- body
        local ret = TestCallSelectorReturnValue.returnSEL()
        print("TestCallSelectorReturnValue.returnSEL()")
        print(ret)
        -- 用这种方式可以调用select
        local runStr = 'return require("luapatch").packClass("TestCallSelectorReturnValue").'..ret.."()"
        local ret = load(runStr)()
        
        local NSDictionary_class = NSDictionary.class()
        assert.equal(luapatch.unpackPoint(ret),luapatch.unpackPoint(NSDictionary_class))
    end)

    --加一个返回block的，检查是否能传给oc调用
    it("block object return value",function ( ... )
        -- body
        local ret = TestCallSelectorReturnValue.returnBlock()
        TestCallSelectorReturnValue.checkBlock(ret)
        ret = TestCallSelectorReturnValue.returnStrParamBlock()
        luapatch.callBlock(ret,'helloworld')
    end)
end)
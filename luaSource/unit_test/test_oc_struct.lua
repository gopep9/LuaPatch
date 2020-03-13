

describe("test LuaPatch api return value", function ()
    -- body
    local luapatch = require("luapatch")
    local TestCallSelectorArgument = luapatch.packClass("TestCallSelectorArgument")
    it("test makeOCStruct", function()

        local ret = luapatch.makeOCStruct("CGRect",1,2,3,4)
        assert.truthy(ret)
        print("CGRect in test makeOCStruct")
        assert.equal(luapatch.convertCGRectToStr(ret),"1.000000,2.000000,3.000000,4.000000")
        local rect = ret

        ret = luapatch.makeOCStruct("CGPoint",1,2)
        assert.truthy(ret)
        print("CGPoint in test makeOCStruct")
        assert.equal(luapatch.convertCGPointToStr(ret),"1.000000,2.000000")
        local point = ret

        ret = luapatch.makeOCStruct("CGSize",1,2)
        assert.truthy(ret)
        print("CGSize in test makeOCStruct")
        assert.equal(luapatch.convertCGSizeToStr(ret),"1.000000,2.000000")
        local size = ret

        ret = luapatch.makeOCStruct("NSRange",1,2)
        assert.truthy(ret)
        print("NSRange in test makeOCStruct")
        assert.equal(luapatch.convertNSRangeToStr(ret),"1,2")
        local range = ret

        --测试是否能在oc中正确接收到
        TestCallSelectorArgument.checkOCStructWithRect_Point_Size_Range(rect,point,size,range)
    end)
end)

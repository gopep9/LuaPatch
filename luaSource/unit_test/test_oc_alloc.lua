


describe("test oc object alloc", function()
    -- body
    local luapatch = require("luapatch")
    local packClass = luapatch.packClass
    local NSString = packClass("NSString")
    local NSMutableString = packClass("NSMutableString")
    local NSArray = packClass("NSArray")
    local NSMutableArray = packClass("NSMutableArray")
    local NSDictionary = packClass("NSDictionary")
    local NSMutableDictionary = packClass("NSMutableDictionary")
    local UIView = packClass("UIView")
    local UIButton = packClass("UIButton")
    local UITextField = packClass("UITextField")
    it("test common class alloc", function()
        -- body
        local ret = NSString.new()
        assert.equal(type(ret),"string")

        ret = NSMutableString.new()
        assert.equal(type(ret),"string")

        local ret = NSArray.alloc().init()
        assert.equal(ret.isKindOfClass(NSArray.class()),1)
        local ret = NSArray.new()
        assert.equal(ret.isKindOfClass(NSArray.class()),1)

        local ret = NSMutableArray.alloc().init()
        assert.equal(ret.isKindOfClass(NSMutableArray.class()),1)
        local ret = NSMutableArray.new()
        assert.equal(ret.isKindOfClass(NSMutableArray.class()),1)

        local ret = NSDictionary.alloc().init()
        assert.equal(ret.isKindOfClass(NSDictionary.class()),1)

        local ret = NSMutableDictionary.alloc().init()
        assert.equal(ret.isKindOfClass(NSMutableDictionary.class()),1)

        local ret = NSArray.alloc().initWithObjects("a","b",luapatch.getNilObject())
        assert.equal(ret.isKindOfClass(NSArray.class()),1)
        print(ret_class)
    end)

    it("test ui class alloc",function( ... )
    	-- body
    	UIView.alloc().init()
    	UIButton.alloc().init()
    	UITextField.alloc().init()
    end)
end)

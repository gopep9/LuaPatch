print("run ViewController in lua")
local luapatch = require("luapatch")
luapatch.setPrintLog(true)
luapatch.defineClass("ViewController")
local packClass = luapatch.packClass
local UIView = packClass("UIView")
local UIColor = packClass("UIColor")
local UIButton = packClass("UIButton")
local ViewController2 = packClass("ViewController2")
local UIColor = packClass("UIColor")
local NSMutableURLRequest = packClass("NSMutableURLRequest")
local NSURL = packClass("NSURL")
local NSURLSession = packClass("NSURLSession")
local TestCallORIG = packClass("TestCallORIG")
local NSString = packClass("NSString")
local DerivedClass = packClass("DerivedClass")
local NSArray = packClass("NSArray")
local NSMutableArray = packClass("NSMutableArray")


luapatch.redefineInstanceMethod("ViewController","updateViewController","ViewController_updateViewController")
luapatch.addInstanceMethod("ViewController","buttonTouch:","ViewController_buttonTouch","void_id")
luapatch.addInstanceMethod("ViewController","buttonTouch2:","ViewController_buttonTouch2","void_id")
luapatch.addInstanceMethod("ViewController","buttonTouch3:","ViewController_buttonTouch3","void_id")
luapatch.addInstanceMethod("ViewController","buttonTouch4:","ViewController_buttonTouch4","void_id")
luapatch.addInstanceMethod("ViewController","buttonTouch5:","ViewController_buttonTouch5","void_id")
luapatch.addInstanceMethod("ViewController","buttonTouch6:","ViewController_buttonTouch6","void_id")
luapatch.addInstanceMethod("ViewController","buttonTouch7:","ViewController_buttonTouch7","void_id")
luapatch.addInstanceMethod("ViewController","buttonTouch8:","ViewController_buttonTouch8","void_id")

-- globalView = {}
nilObject = luapatch.getNilObject()
nullObject = luapatch.getNullObject()
globalApplePay = {}
globalButtonFrame8 = {}
function ViewController_updateViewController(instance)
    print(instance)
    print("call updateViewController")
    local rect = luapatch.makeOCStruct("CGRect",0,0,200,600)
    local view = UIView.alloc()
    view.initWithFrame(rect)
    local green = UIColor.greenColor()
    view.setBackgroundColor(green)
    instance.view().addSubview(view)
    local globalView = view
    -- globalView.retain() --什么时候保证不再使用调用release函数，并且置空globalView
    instance.setProp_forKey(globalView,"globalView")
    instance.setProp_forKey("testvalue","testkey")

    --测试按钮响应
    local button = UIButton.buttonWithType(1)
    local buttonFrame = luapatch.makeOCStruct("CGRect",0,100,200,50)
    button.setFrame(buttonFrame)
    button.setTitle_forState("请点击我",0)
    view.addSubview(button)
    button.addTarget_action_forControlEvents(instance,"buttonTouch:",64)

    --测试页面跳转
    local button2 = UIButton.buttonWithType(1)
    local buttonFrame2 = luapatch.makeOCStruct("CGRect",0,150,200,50)
    button2.setFrame(buttonFrame2)
    button2.setTitle_forState("跳转到新页面",0)
    view.addSubview(button2)
    button2.addTarget_action_forControlEvents(instance,"buttonTouch2:",64)

    --测试网络请求
    local button3 = UIButton.buttonWithType(1)
    local buttonFrame3 = luapatch.makeOCStruct("CGRect",0,200,200,50)
    button3.setFrame(buttonFrame3)
    button3.setTitle_forState("请求简书并返回结果",0)
    view.addSubview(button3)
    button3.addTarget_action_forControlEvents(instance,"buttonTouch3:",64)

    --测试苹果支付
    local button4 = UIButton.buttonWithType(1)
    local buttonFrame4 = luapatch.makeOCStruct("CGRect",0,250,200,50)
    button4.setFrame(buttonFrame4)
    button4.setTitle_forState("打开苹果支付",0)
    view.addSubview(button4)
    button4.addTarget_action_forControlEvents(instance,"buttonTouch4:",64)
    globalApplePay = packClass("ApplePay").new()
    print("globalApplePay:")
    print(globalApplePay)
    globalApplePay.retain()

    --测试是否能调用被替代的源实现
    local button5 = UIButton.buttonWithType(1)
    local buttonFrame5 = luapatch.makeOCStruct("CGRect",0,300,200,50)
    button5.setFrame(buttonFrame5)
    button5.setTitle_forState("测试是否能调用原实现",0)
    view.addSubview(button5)
    button5.addTarget_action_forControlEvents(instance,"buttonTouch5:",64)

    --测试是否能调用父类的函数，包括父类是lua实现的
    local button6 = UIButton.buttonWithType(1)
    local buttonFrame6 = luapatch.makeOCStruct("CGRect",0,350,200,50)
    button6.setFrame(buttonFrame6)
    button6.setTitle_forState("测试是否能调用父类实现",0)
    view.addSubview(button6)
    button6.addTarget_action_forControlEvents(instance,"buttonTouch6:",64)

    --super 
    local button7 = UIButton.buttonWithType(1)
    local buttonFrame7 = luapatch.makeOCStruct("CGRect",0,400,200,50)
    button7.setFrame(buttonFrame7)
    button7.setTitle_forState("dispatch测试",0)
    view.addSubview(button7)
    button7.addTarget_action_forControlEvents(instance,"buttonTouch7:",64)

    --内存泄露测试，调用上面的接口1000遍
    local button8 = UIButton.buttonWithType(1)
    local buttonFrame8 = luapatch.makeOCStruct("CGRect",0,450,200,50)
    button8.setFrame(buttonFrame8)
    globalButtonFrame8 = buttonFrame8
    -- globalButtonFrame8.retain()
    luapatch.retainObject(globalButtonFrame8)

    button8.setTitle_forState("运行lua单元测试",0)
    view.addSubview(button8)
    button8.addTarget_action_forControlEvents(instance,"buttonTouch8:",64)
end

function ViewController_buttonTouch(instance,button)
    print("call buttonTouch")
    button.setTitle_forState("hello world",0)
    local globalView = instance.getProp("globalView")
    local nilTest = instance.getProp("test")
    -- print("nilTest is ")
    -- print(type(nilTest))
    if luapatch.isPointEqual(nilTest,nilObject) then
        print("nilTest is nil")
    end
    -- globalView ~= nil
    if not luapatch.isPointEqual(globalView,nilObject) then
        globalView.setBackgroundColor(UIColor.yellowColor())
        globalView = nil
    end
    local teststr = instance.getProp("testkey")
    print("testkey is "..teststr)
    print("buttonTouch done")
end

function ViewController_buttonTouch2(instance,button)
    local vc2 = ViewController2.alloc().init()
    vc2.view().setBackgroundColor(UIColor.yellowColor())
    instance.presentViewController_animated_completion(vc2,true,nilObject)
end

function ViewController_buttonTouch3(instance,button)
    -- button.setTitle_forState("a",0)
    local url = NSURL.URLWithString("https://www.jianshu.com")
    local request = NSMutableURLRequest.requestWithURL(url)
    local session = NSURLSession.sharedSession()
    local block = luapatch.convertLuaBlockToObjcBlock('ViewController_block','void_id_id_id')
    local task = session.dataTaskWithRequest_completionHandler(request,block)
    task.resume()
end

function ViewController_block(instance,data,response,error)--这里需要对输入的指针进行pack
    -- body
    print("call ViewController_block")
    --local retMsg = NSString.alloc().initWithData_encoding(data,4) -- 这里使用nsstring alloc会有问题
    local retData = luapatch.packPoint(data).bytes()
    print("retData:"..luapatch.tableToStr(retData))
    local retMsg = NSString.stringWithUTF8String(retData)
    print("retMsg "..retMsg)
    -- local retMsg = NSString.stringWithUTF8String(packPoint(data).bytes())
end

function ViewController_buttonTouch4(instance,button)
    -- body
    globalApplePay.pay("com.zsglrxll60z.apple")
end

function ViewController_buttonTouch5(instance,button)
    -- body
    funcInstanceRet = TestCallORIG.new().funcInstance()
    print("call TestCallORIG funcInstance in lua and return")
    print(funcInstanceRet)
    funcClassRet = TestCallORIG.funcClass()
    print("call TestCallORIG funcClass in lua and return")
    print(funcClassRet)
end

function ViewController_buttonTouch6(instance,button)
    -- body
    funcInstanceRet = DerivedClass.new().funcInstance()
    print("call DerivedClass funcInstance in lua and return")
    print(funcInstanceRet)
    funcClassRet = DerivedClass.funcClass()
    print("call DerivedClass funcClass in lua and return")
    print(funcClassRet)
    -- 会因为无限循环栈溢出闪退，注释掉
    -- 具体原因是在LPForwardInvocation函数中因为没有找到对应的lua函数而调用了LPExecuteORIGForwardInvocation
    -- 而在LPExecuteORIGForwardInvocation中又因为对象本身不能响应这个方法二调用了superForwardIMP(slf, @selector(forwardInvocation:), invocation);
    funcInstanceRet2 = DerivedClass.new().funcInstance2()
    print("call DerivedClass funcInstance2 in lua and return")
    print(funcInstanceRet2)
    funcClassRet2 = DerivedClass.funcClass2()
    print("call DerivedClass funcClass2 in lua and return")
    print(funcClassRet2)
end

function ViewController_buttonTouch7(instance,button)
    -- body
    print("call buttonTouch7")
    local arg1 = NSMutableArray.alloc().init()
    arg1.addObject("value1")
    arg1.addObject("value2")
    arg1.addObject("value3")
    luapatch.dispatchAfter("ViewController_dispatchAfter1",5,arg1)
    luapatch.dispatchAsyncMain("ViewController_dispatchAsyncMain1",arg1)
    luapatch.dispatchSyncMain("ViewController_dispatchSyncMain1",arg1)
end

function ViewController_dispatchAfter1(argument)
    -- body
    print("call ViewController_dispatchAfter1 in lua")
    luapatch.printObjcObject(argument)
end

function ViewController_dispatchAsyncMain1(argument)
    -- body
    print("call ViewController_dispatchAsyncMain1 in lua")
    luapatch.printObjcObject(argument)
end

function ViewController_dispatchSyncMain1(argument)
    -- body
    print("call ViewController_dispatchSyncMain1 in lua")
    luapatch.printObjcObject(argument)
end

function ViewController_buttonTouch8(instance,button)
    require("unit_test.unitTest")
end

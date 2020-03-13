print("run ViewController2 in lua")
local luapatch = require("luapatch")
luapatch.defineClass("ViewController2:UIViewController")
local loadClass = luapatch.loadClass

luapatch.addInstanceMethod("ViewController2","viewDidLoad","ViewController2_ViewDidLoad","void")
luapatch.addInstanceMethod("ViewController2","buttonTouch:","ViewController2_dismissViewControllerButtonTouch","void_id")

function ViewController2_ViewDidLoad(instance)
    instance.super().viewDidLoad()
    local UIButton = luapatch.packClass("UIButton")
    local button = UIButton.buttonWithType(1)
    local buttonFrame = luapatch.makeOCStruct("CGRect",0,100,200,100)
    button.setFrame(buttonFrame)
    button.setTitle_forState("返回上一个页面",0)
    instance.view().addSubview(button)
    button.addTarget_action_forControlEvents(instance,"buttonTouch:",64)
end

function ViewController2_dismissViewControllerButtonTouch(instance,button)
    instance.dismissViewControllerAnimated_completion(true,nilObject)
end


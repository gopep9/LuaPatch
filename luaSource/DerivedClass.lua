local luapatch = require("luapatch")
luapatch.redefineInstanceMethod("DerivedClass","funcInstance","DerivedClass_funcInstance")
luapatch.redefineClassMethod("DerivedClass","funcClass","DerivedClass_funcClass")
luapatch.redefineInstanceMethod("DerivedClass","funcInstance2","DerivedClass_funcInstance2")
luapatch.addClassMethod("DerivedClass","funcClass2","DerivedClass_funcClass2","int")
luapatch.addInstanceMethod("DerivedClass","init","DerivedClass_init","id")

function DerivedClass_funcInstance(instance)
    -- body
    print("call DerivedClass_funcInstance")
    return instance.ORIGfuncInstance()+instance.super().funcInstance()
end

function DerivedClass_funcClass(className)
    -- body
    print("call DerivedClass_funcClass")
    return luapatch.packClass(className).ORIGfuncClass()+luapatch.packClass("BaseClass").funcClass()
end

function DerivedClass_funcInstance2(instance)
    -- body
    print("call DerivedClass_funcInstance2")
    return instance.super().funcInstance2();
end

function DerivedClass_funcClass2(className)
    -- body
    print("call DerivedClass_funcClass2")
    return luapatch.packClass("BaseClass").funcClass2();
end

function DerivedClass_init(instance)
    -- body
    print("DerivedClass_init")
    instance.super().init()
    return instance
end

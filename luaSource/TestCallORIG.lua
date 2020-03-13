local luapatch = require("luapatch")
luapatch.redefineInstanceMethod("TestCallORIG","funcInstance","TestCallORIG_funcInstance")
luapatch.redefineClassMethod("TestCallORIG","funcClass","TestCallORIG_funcClass")

function TestCallORIG_funcInstance(instance)
    -- body
    print("call TestCallORIG_funcInstance")
    return instance.ORIGfuncInstance()+1
end

function TestCallORIG_funcClass(className)
    -- body
    print("call TestCallORIG_funcClass")
    return luapatch.packClass(className).ORIGfuncClass()+1
end
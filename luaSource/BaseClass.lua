local luapatch = require("luapatch")
luapatch.addInstanceMethod("BaseClass","funcInstance2","BaseClass_funcInstance2","int")
luapatch.addClassMethod("BaseClass","funcClass2","BaseClass_funcClass2","int")
--4种情况，有oc有 lua 覆盖
--oc没有 lua 添加
--oc有 lua没有
--上面三种都会调用到oc中实现的祖父函数，（都是将ORIGfuncInstance命名为父类函数的实现）
--lua有 oc没有（这个会调用到派生类中的实现，ORIGfuncInstance被命名为派生类中的实现了）
--super这个还是太复杂了，是否有简单的方法
--或者总结规律
--规定之后

function BaseClass_funcInstance2(instance)
    -- body
    print("call BaseClass_funcInstance2")
    return 1;
end

function BaseClass_funcClass2(className)
    -- body
    print("call BaseClass_funcClass2")
    return 2;
end

print("run main.lua")

require("ViewController")
require("ViewController2")
require("ApplePay")
require("BaseClass")
require("DerivedClass")
require("TestCallORIG")
-- 各文件的lua函数命名不能重复
-- 规范的写法可能是lua函数需要添加上类名
--require("unitTest")

--直接跑单元测试
-- require("unit_test.unitTest")
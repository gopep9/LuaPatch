-- 文档
-- http://olivinelabs.com/busted/

-- 读取文件添加到执行的字符串
total_str = ""

--需要测试的文件数组
unit_test_array = {
"unit_test/test_head.lua",
"unit_test/test_oc_struct.lua",
"unit_test/test_oc_alloc.lua",
"unit_test/test_call_orig.lua",
"unit_test/test_call_selector_argument.lua",
"unit_test/test_call_selector_return_value.lua",
"unit_test/test_forward_argument.lua",
"unit_test/test_call_super.lua",
"unit_test/test_dispatch.lua",
"unit_test/test_new_class.lua",
"unit_test/test_call_variable_parameter_function.lua"
}


--遍历数组
for i = 1,#unit_test_array do
	local file = io.open(unit_test_array[i],"r")
	file_str = file:read("*a")
	file:close()
	total_str = total_str.."\n"..file_str
end


-- print("unit_test str")
-- print(total_str)

load(total_str)()
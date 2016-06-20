local class = require 'ext.class'
local CClass = getmetatable(require 'c')

local CppClass = class(CClass)
CppClass.CC = 'g++'
CppClass.srcSuffix = '.cpp'
CppClass.funcPrefix = 'extern "C"'

return CppClass()

local class = require 'ext.class'
local CClass = getmetatable(require 'ffi-c.c')

local CppClass = class(CClass)
CppClass.srcSuffix = '.cpp'
CppClass.funcPrefix = 'extern "C"'

return CppClass()

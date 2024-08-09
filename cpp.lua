local CClass = getmetatable(require 'ffi-c.c')

local CppClass = CClass:subclass()
CppClass.srcSuffix = '.cpp'
CppClass.funcPrefix = 'extern "C"'

return CppClass()

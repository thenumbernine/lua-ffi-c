local ffi = require 'ffi'
local class = require 'ext.class'
local file = require 'ext.file'
local table = require 'ext.table'

local CClass = class()

CClass.CC = 'gcc'
CClass.CFLAGS = '-Wall -fPIC'
CClass.LDFLAGS = '-dynamiclib'
CClass.srcSuffix = '.c'
CClass.objSuffix = '.o'
CClass.libPrefix = 'lib'
CClass.libSuffix = '.dylib'
function CClass:init()
	self.libfiles = table()
end

function CClass:cleanup()
	for _,libfile in ipairs(self.libfiles) do
		os.remove(libfile)
	end
end

local fileIndex = 1	-- have to use one of these for all so library names don't overlap
function CClass:compile(code)
	-- 1) write out code
	local name = 'tmp'..fileIndex
	fileIndex = fileIndex + 1
	local srcfile = name..self.srcSuffix
	local objfile = name..self.objSuffix
	local libfile = self.libPrefix..name..self.libSuffix
	self.libfiles:insert(libfile)
	file[srcfile] = code
	-- 2) compile to so
	assert(0 == os.execute(self.CC..' '..self.CFLAGS..' -c -o '..objfile..' '..srcfile), "failed to build c code")
	assert(0 == os.execute(self.CC..' '..self.CFLAGS..' '..self.LDFLAGS..' -o '..libfile..' '..objfile), "failed to link c code")
	-- 3) load into ffi
	local lib = ffi.load(libfile)
	-- 4) don't delete the dynamic library! some OS's get mad when you delete a dynamically-loaded shared object
	-- but go ahead and delete the source code
	-- TODO ffi __gc delete the dll file once the lib is no longer used
	os.remove(srcfile)
	os.remove(objfile)
	return lib
end

function CClass:func(returnType, name, params, body, prefix)
	local prototype = returnType..' '..name..'('..params..')'
	local lib = self:compile((self.funcPrefix or '')..' '..prototype..'{'..body..'}')
	ffi.cdef(prototype..';')
	return lib
end

return CClass()

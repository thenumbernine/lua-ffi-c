local ffi = require 'ffi'
local class = require 'ext.class'
local file = require 'ext.file'
local table = require 'ext.table'

local CClass = class()

CClass.CC = 'gcc'
CClass.CFLAGS = '-Wall -fPIC'
CClass.LDFLAGS = assert(({
	OSX = '-dynamiclib',
	Linux = '-shared',
})[ffi.os])
CClass.srcSuffix = '.c'
CClass.objSuffix = '.o'
CClass.libPrefix = 'lib'
CClass.libSuffix = assert(({
	OSX = '.dylib',
	Linux = '.so',
})[ffi.os])


-- this has to hold all compile classes - no overlaps are allowed
-- because it is used in the unique naming
-- keep track of stuff from __gc to :cleanup()
local cobjs = table()	

ffi.cdef[[
typedef struct {
	int ptr[1];
} CClass_gc_t;
]]
local CClass_gc_t = ffi.metatype('CClass_gc_t', {
	__gc = function(obj)
		local index = obj.ptr[0]
		if index ~= 0 then
			local cobj = cobjs[index]
			if cobj then
				cobj:cleanup()
			end
			obj.ptr[0] = 0
		end
	end,
})

function CClass:init()
	self.libfiles = table()
	cobjs:insert(self)
	self.cobjIndex = #cobjs
	self.id = CClass_gc_t()
	self.id.ptr[0] = self.cobjIndex
end

function CClass:cleanup()
	for _,libfile in ipairs(self.libfiles) do
		os.remove(libfile)
	end
	cobjs[self.cobjIndex] = nil
end

function CClass:compile(code)
	-- 1) write out code
	local libIndex = #self.libfiles+1
	local name = 'libtmp-'..self.cobjIndex..'-'..libIndex
	local srcfile = name..self.srcSuffix
	local objfile = name..self.objSuffix
	local libfile = self.libPrefix..name..self.libSuffix
	self.libfiles:insert(libfile)
	file[srcfile] = code
	-- 2) compile to so
	local cmd = self.CC..' '..self.CFLAGS..' -c -o '..objfile..' '..srcfile
	--print(cmd)
	assert(os.execute(cmd), "failed to build c code")
	local cmd = self.CC..' '..self.CFLAGS..' '..self.LDFLAGS..' -o '..libfile..' '..objfile
	--print(cmd)	
	assert(os.execute(cmd), "failed to link c code")
	-- 3) load into ffi
	local lib = ffi.load('./'..libfile)
	-- 4) don't delete the dynamic library! some OS's get mad when you delete a dynamically-loaded shared object
	-- but go ahead and delete the source code
	-- ffi __gc will delete the dll file once the lib is no longer used
	os.remove(srcfile)
	os.remove(objfile)
	return lib
end

function CClass:func(prototype, body)
	local lib = self:compile((self.funcPrefix or '')..' '..prototype..'{'..body..'}')
	ffi.cdef(prototype..';')
	return lib
end

return CClass()

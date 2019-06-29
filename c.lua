local ffi = require 'ffi'
local class = require 'ext.class'
local file = require 'ext.file'
local table = require 'ext.table'
local io = require 'ext.io'

-- TODO lua-make, move the classes into a separate library of compiler specs, and use it here too
local CClass = class()

CClass.CC = ffi.os == 'Windows' and 'cl.exe' or 'gcc'
CClass.CFLAGS = ({
	OSX = '-Wall -fPIC',
	Linux = '-Wall -fPIC',
	Windows = '/nologo',
})[ffi.os]
CClass.LDFLAGS = assert(({
	OSX = '-dynamiclib',
	Linux = '-shared',
	Windows = '/dll'
})[ffi.os])
CClass.compileOutputFlag = ffi.os == 'Windows' and '/Fo' or '-o '
CClass.srcSuffix = '.c'
CClass.objSuffix = ffi.os == 'Windows' and '.obj' or '.o'
CClass.LD = ffi.os == 'Windows' and 'link.exe' or 'gcc'	-- or 'ld' ?
CClass.linkOutputFlag = ffi.os == 'Windows' and '/out:' or '-o '
CClass.libPrefix = ffi.os == 'Windows' and '' or 'lib'
CClass.libSuffix = assert(({
	OSX = '.dylib',
	Linux = '.so',
	Windows = '.dll',
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

local function exec(cmd)
	print(cmd)
	local results = table.pack(os.execute(cmd))
	--print(require 'ext.tolua'(results))
	print(table.unpack(results, 1, results.n))
	return table.unpack(results, 1, results.n)
end

function CClass:compile(code)
	-- 1) write out code
	local libIndex = #self.libfiles+1
	local name = 'libtmp-'..self.cobjIndex..'-'..libIndex
	local srcfile = name..self.srcSuffix
	local objfile = name..self.objSuffix
	local result = {}
	result.libfile = self.libPrefix..name..self.libSuffix
	self.libfiles:insert(result.libfile)
	file[srcfile] = code
	-- 2) compile to so
	local cmd = self.CC..' '..self.CFLAGS..' -c '..self.compileOutputFlag..objfile..' '..srcfile
		--..' > tmp 2>&1'
		..' | tee tmp'
	--print(cmd)
	local status = exec(cmd)
	result.compileLog = io.readfile'tmp'
	os.remove'tmp'
	if not status then
		result.error = "failed to build c code"
		return result
	end
	local cmd = self.LD..' '..self.CFLAGS..' '..self.LDFLAGS..' '..self.linkOutputFlag..result.libfile..' '..objfile
		--..' > tmp 2>&1'
		..' | tee tmp'
	--print(cmd)
	local status = exec(cmd)
	result.linkLog = io.readfile'tmp'
	os.remove'tmp'
	if not status then
		result.error = "failed to link c code"
		return result
	end
	-- 3) load into ffi
	result.lib = ffi.load('./'..result.libfile)
	-- 4) don't delete the dynamic library! some OS's get mad when you delete a dynamically-loaded shared object
	-- but go ahead and delete the source code
	-- ffi __gc will delete the dll file once the lib is no longer used
--	os.remove(srcfile)
--	os.remove(objfile)
	return result
end

function CClass:func(prototype, body)
	local lib = self:compile((self.funcPrefix or '')..' '..prototype..'{'..body..'}')
	ffi.cdef(prototype..';')
	return lib
end

return CClass()

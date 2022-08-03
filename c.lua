local ffi = require 'ffi'
local class = require 'ext.class'
local file = require 'ext.file'
local table = require 'ext.table'
local io = require 'ext.io'

local MakeEnv = require 'make.env'

local CClass = class()
CClass.srcSuffix = '.c'
CClass.funcPrefix = ''

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

	self.env = MakeEnv()
	self.env.distName = name
	self.env.distType = 'lib'
	self.env.build = 'release'	-- TODO make a ctor
	self.env.useStatic = false	-- TODO arg

-- [[
	self.env.cppver = 'c99'		-- TODO this should be 'std' or 'stdver' instead of 'cppver' ... since this isn't C++, it's C
	self.env:preConfig()		-- TODO ctor instead?
	self.env:postConfig()
--]]
--[[ requires buildinfo file ...
	self.env:setupBuild'release'
--]]

-- TODO do this in make.env
-- determine compiler based on suffix
if self.env.compiler == 'g++' then
	self.env.compiler = 'gcc'
end
if self.env.linker == 'g++' then
	self.env.linker = 'gcc'
	self.env.libs:insert'm'
end
	
	-- TODO build this into the make.env somehow?
	if self.env.name == 'msvc' then
		code = '__declspec(dllexport) ' .. code
	end
	if self.funcPrefix then
		code = self.funcPrefix..' '..code
	end

	local srcfile = name..self.srcSuffix
	local objfile = name..self.env.objSuffix
	local result = {}
	result.libfile = self.env.libPrefix..name..self.env.libSuffix
	self.libfiles:insert(result.libfile)
	file[srcfile] = code
	
	-- 2) compile to so
	self.env.objLogFile = name..'-obj.log'
	local status, compileLog = self.env:buildObj(objfile, srcfile) 	-- TODO allow capture output log
	result.compileLog = compileLog 
	if not status then
		result.error = "failed to build c code"
		return result
	end
	
	self.env.distLogFile = name..'-dist.log'
	local status, linkLog = self.env:buildDist(result.libfile, {objfile})	-- TODO allow capture output log
	result.linkLog = linkLog
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
	local result = self:compile(prototype..'{'..body..'}')
	if result.error then error(require 'ext.tolua'(result)) end
	ffi.cdef(prototype..';')
	return result.lib
end

return CClass()

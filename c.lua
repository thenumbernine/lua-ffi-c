local ffi = require 'ffi'
local GCWrapper = require 'ffi.gcwrapper.gcwrapper'
local class = require 'ext.class'
local path = require 'ext.path'
local table = require 'ext.table'

local MakeEnv = require 'make.env'


-- this has to hold all compile classes - no overlaps are allowed
-- because it is used in the unique naming
-- keep track of stuff from __gc to :cleanup()
local cobjs = table()

local CClass = class(GCWrapper{
	gctype = 'CClass_gc_t',
	ctype = 'int',
	release = function(ptr)
		local index = ptr[0]
--print('releasing, ptr[0]='..index)
		if index ~= 0 then
--print('releasing, ptr[0] nonzero')
			local cobj = cobjs[index]
--print('releasing, cobj=', cobj)
			if cobj then
--print('releasing, cleanup')
				cobj:cleanup()
			end
			ptr[0] = 0
		end
	end,
})

CClass.srcSuffix = '.c'
CClass.funcPrefix = ''

function CClass:init()
	CClass.super.init(self)
	self.libfiles = table()
	cobjs:insert(self)
	self.cobjIndex = #cobjs
	self.gc.ptr[0] = self.cobjIndex
end

function CClass:cleanup()
--print'cleaning up'
	for _,libfile in ipairs(self.libfiles) do
		path(libfile):remove()
-- TODO remove the other files , not just the library?
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

-- what to set for windows?
function CClass:getBuildDir()
	return '/tmp'
end

-- setup build env obj and write code file
function CClass:setup(args, result)
	result = result or {}

	local code = args.code

	-- 1) write out code
	local libIndex = #self.libfiles+1
	local name = self:getBuildDir()..'/libtmp_'..self.cobjIndex..'_'..libIndex

	self.env = MakeEnv()
	self.env.distName = name
	self.env.distType = 'lib'
	self.env.build = args.build or 'release'	-- TODO make a ctor
	self.env.useStatic = false	-- TODO arg

-- [[
	self.env.cppver = args.cppver or 'c11'		-- TODO this should be 'std' or 'stdver' instead of 'cppver' ... since this isn't C++, it's C
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

	result.srcfile = name..self.srcSuffix
	result.objfile = name..self.env.objSuffix
	result.libfile = self.env.libPrefix..name..self.env.libSuffix
	self.libfiles:insert(result.libfile)
	path(result.srcfile):write(code)

	return result
end

function CClass:compile(args, result)
	result = result or {}
	local name = self.env.distName
	self.env.objLogFile = name..'-obj.log'
	local status, compileLog = self.env:buildObj(result.objfile, result.srcfile) 	-- TODO allow capture output log
	result.compileLog = compileLog
	if not status then
		result.error = "failed to build c code"
	end
	return result
end

function CClass:link(args, result)
	result = result or {}

	local objfiles = table{result.objfile}
	self:addExtraObjFiles(objfiles, result)

	local name = self.env.distName
	self.env.distLogFile = name..'-dist.log'
	local status, linkLog = self.env:buildDist(result.libfile, objfiles)	-- TODO allow capture output log
	result.linkLog = linkLog
	if not status then
		result.error = "failed to link c code"
	end
	return result
end

function CClass:load(args, result)
	result.lib = ffi.load('./'..result.libfile)
	return result
end

-- TODO rename 'result' to 'context'
function CClass:build(args, result)
	if type(args) == 'string' then
		args = {code = args}
	else
		assert(type(args) == 'table')
	end

	result = result or {}

	result = self:setup(args, result)

	-- 2) compile to so
	result = self:compile(args, result)
	if result.error then return result end

	result = self:link(args, result)
	if result.error then return result end

	-- 3) load into ffi
	result = self:load(args, result)

	-- 4) don't delete the dynamic library! some OS's get mad when you delete a dynamically-loaded shared object
	-- but go ahead and delete the source code
	-- ffi __gc will delete the dll file once the lib is no longer used
--	path(result.srcfile):remove()
--	path(result.objfile):remove()

	return result
end

-- subclasses can add any other .o's
function CClass:addExtraObjFiles(objfiles)
end

function CClass:func(prototype, body)
	local result = self:build(prototype..'{'..body..'}')
	if result.error then error(require 'ext.tolua'(result)) end
	ffi.cdef(prototype..';')
	return result.lib
end

return CClass()

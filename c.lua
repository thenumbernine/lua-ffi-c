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
function CClass:setup(args, ctx)
	ctx = ctx or {}
	ctx.srcSuffix = ctx.srcSuffix or self.srcSuffix

	-- ok code is optional for when you use this for just linking files
	ctx.code = args.code

	-- 1) write out code
	-- TODO what happens when we want unique filenames but don't want to delete on cleanup?
	-- 	or what if we run two ffi-c's simultaneously?
	-- 	need better name picker ...
	local libIndex = #self.libfiles+1
	ctx.name = 'libtmp_'..self.cobjIndex..'_'..libIndex

	ctx.env = MakeEnv()
	ctx.env.distName = ctx.name
	ctx.env.distType = 'lib'
	ctx.env.build = args.build or 'release'	-- TODO make a ctor
	ctx.env.useStatic = false	-- TODO arg

-- [[
	ctx.env.cppver = args.cppver or ctx.cppver or 'c11'		-- TODO this should be 'std' or 'stdver' instead of 'cppver' ... since this isn't C++, it's C
	ctx.env:preConfig()		-- TODO ctor instead?
	ctx.env:postConfig()
	ctx.env.include:append(ctx.include or {})
--]]
--[[ requires buildinfo file ...
	ctx.env:setupBuild'release'
--]]

	-- TODO do this in make.env
	-- determine compiler based on suffix
	if ctx.srcSuffix == '.c' then
		if ctx.env.compiler == 'g++' then
			ctx.env.compiler = 'gcc'
		end
		if ctx.env.linker == 'g++' then
			ctx.env.linker = 'gcc'
			ctx.env.libs:insert'm'
		end
	end

	if ctx.code then	-- (in case I'm using this for just linking)
		-- TODO build this into the make.env somehow?
		if ctx.env.name == 'msvc' then
			ctx.code = '__declspec(dllexport) ' .. ctx.code
		end
	end

	ctx.srcfile = self:getBuildDir()..'/'..ctx.name..ctx.srcSuffix
	ctx.objfile = self:getBuildDir()..'/'..ctx.name..ctx.env.objSuffix
	ctx.libfile = self:getBuildDir()..'/'..ctx.env.libPrefix..ctx.name..ctx.env.libSuffix
	self.libfiles:insert(ctx.libfile)	-- collect lib files for cleanup afterwards
	if ctx.code then
		assert(path(ctx.srcfile):write(ctx.code))
	end

	return ctx
end

function CClass:compile(args, ctx)
	ctx = ctx or {}
	ctx.env.objLogFile = self:getBuildDir()..'/'..ctx.name..'-obj.log'
	local status, compileLog = ctx.env:buildObj(ctx.objfile, ctx.srcfile) 	-- TODO allow capture output log
	ctx.compileLog = compileLog
	if not status then
		ctx.error = "failed to build c code"
	end
	return ctx
end

function CClass:link(args, ctx)
	ctx = ctx or {}

	local objfiles = table{ctx.objfile}
	self:addExtraObjFiles(objfiles, ctx)

	ctx.env.distLogFile = self:getBuildDir()..'/'..ctx.name..'-dist.log'
	local status, linkLog = ctx.env:buildDist(ctx.libfile, objfiles)	-- TODO allow capture output log
	ctx.linkLog = linkLog
	if not status then
		ctx.error = "failed to link c code"
	end
	return ctx
end

function CClass:load(args, ctx)
	ctx.lib = ffi.load(ctx.libfile)
	return ctx
end

-- TODO rename 'ctx' to 'context'
function CClass:build(args, ctx)
	if type(args) == 'string' then
		args = {code = args}
	else
		assert(type(args) == 'table')
	end

	ctx = ctx or {}

	ctx = self:setup(args, ctx)

	-- 2) compile to so
	ctx = self:compile(args, ctx)
	if ctx.error then return ctx end

	ctx = self:link(args, ctx)
	if ctx.error then return ctx end

	-- 3) load into ffi
	ctx = self:load(args, ctx)
	if ctx.error then return ctx end

	-- 4) don't delete the dynamic library! some OS's get mad when you delete a dynamically-loaded shared object
	-- but go ahead and delete the source code
	-- ffi __gc will delete the dll file once the lib is no longer used
--	path(ctx.srcfile):remove()
--	path(ctx.objfile):remove()

	return ctx
end

-- subclasses can add any other .o's
function CClass:addExtraObjFiles(objfiles)
end

function CClass:func(prototype, body)
	local code = prototype..'{'..body..'}'

	-- for using ffi-c in the lazy sense:
	if self.funcPrefix then
		code = self.funcPrefix..' '..code
	end

	local ctx = self:build(code)
	if ctx.error then error(require 'ext.tolua'(ctx)) end
	ffi.cdef(prototype..';')
	return ctx
end

return CClass()

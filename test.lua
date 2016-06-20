#!/usr/bin/env luajit

local c = require 'c'
local cpp = require 'cpp'

local libsum = c:func('int', 'sum', 'int a, int b', 'return a + b;')
print(libsum.sum(2,3))
local libmul = cpp:func('int', 'mul', 'int a, int b', 'return a + b;')
print(libmul.mul(2,3))

c:cleanup()
cpp:cleanup()

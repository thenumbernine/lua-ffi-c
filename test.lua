#!/usr/bin/env luajit

local c = require 'ffi-c.c'
local cpp = require 'ffi-c.cpp'

local sum = c:func('int sum(int a, int b)', 'return a + b;')
print(sum.sum(2,3))
local mul = cpp:func('int mul(int a, int b)', 'return a * b;')
print(mul.mul(2,3))

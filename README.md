# Write C/C++ code inline in your Lua code!

For the lazy individuals who want to include optimized C++ code in their Lua code,
but don't want to bother with *compiling* code,
this is the library for you!

You can either manually invoke the compiler and the ffi prototype like so:

```lua
local cpp = require 'cpp'
cpp:compile[[ int sum(int a, int b) { return a + b; } ]]
local ffi = require 'ffi'
ffi.cdef[[ int sum(int a, int b); ]]
```

or, for the truly lazy programmer, you can combine both these actions in one fell swoop:

```lua
local cpp = require 'cpp'
cpp:func('int sum (int a, int b)', 'return a + 1;')
```

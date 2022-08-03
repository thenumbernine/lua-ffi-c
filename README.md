[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=KYWUWS86GSFGL)

# Write C/C++ code inline in your Lua code!

For the lazy individuals who want to include optimized C++ code in their Lua code,
but don't want to bother with *compiling* code,
this is the library for you!

You can either manually invoke the compiler and the ffi prototype like so:

```lua
local cpp = require 'cpp'
local lib = cpp:compile[[ int sum(int a, int b) { return a + b; } ]]
local ffi = require 'ffi'
ffi.cdef[[ int sum(int a, int b); ]]
print(lib.sum(a,b))
```

or, for the truly lazy programmer, you can combine both these actions in one fell swoop:

```lua
local cpp = require 'cpp'
local lib = cpp:func('int sum (int a, int b)', 'return a + 1;')
print(lib.sum(a,b))
```

Depends on my lua-ext, lua-template, and lua-make libraries

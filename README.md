# Write C/C++ code inline in your Lua code!

[![Donate via Stripe](https://img.shields.io/badge/Donate-Stripe-green.svg)](https://buy.stripe.com/00gbJZ0OdcNs9zi288)<br>
[![Donate via Bitcoin](https://img.shields.io/badge/Donate-Bitcoin-green.svg)](bitcoin:37fsp7qQKU8XoHZGRQvVzQVP8FrEJ73cSJ)<br>

For the lazy individuals who want to include optimized C++ code in their Lua code,
but don't want to bother with *compiling* code,
this is the library for you!

You can either manually invoke the compiler and the ffi prototype like so:

```lua
local cpp = require 'cpp'
local build = cpp:build[[ int sum(int a, int b) { return a + b; } ]]
local ffi = require 'ffi'
ffi.cdef[[ int sum(int a, int b); ]]
print(build.lib.sum(a,b))
```

or, for the truly lazy programmer, you can combine both these actions in one fell swoop:

```lua
local cpp = require 'cpp'
local build = cpp:func('int sum (int a, int b)', 'return a + 1;')
print(build.lib.sum(a,b))
```

Depends on my lua-ext, lua-template, and lua-make libraries

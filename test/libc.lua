local libc = require 'lsh.libc'

local glob_ex1 = "/proc/[0-9]*/exe"
local glob_ex2 = "/proc/baa"

local res, err = libc.glob(glob_ex1)
assert(res)
for _, v in ipairs(res) do
  print(v)
end

local res, err = libc.glob(glob_ex2)
assert(err)

local libc = require 'lsh.libc'

local glob_ex1 = "/proc/[0-9]*/exe"

print('-- glob --')
local res, err = libc.glob(glob_ex1)
assert(res)
for _, v in ipairs(res) do
  assert(v)
end

local sh = require 'lsh'

print('-- stringx split --')
do
  local buf = 'one two  three'
  local res = sh.stringx.split(buf)
  assert(res[1] == 'one')
  assert(res[2] == 'two')
  assert(res[3] == 'three')

  local res = sh.stringx.split(buf, 't')
  assert(res[1] == 'one ')
  assert(res[2] == 'wo  ')
  assert(res[3] == 'hree')

end

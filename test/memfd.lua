local sh = require 'lsh'

print('-- memfd --')
do
  local buf = '123'
  local memfd = sh.memfd(buf)

  memfd:write(buf)
  memfd:write('blah')
  memfd:seek(0)

  local res = memfd:read()
  print(res)
  local res, err = memfd:read()
  print(res, #res, err)

  print(memfd)
end

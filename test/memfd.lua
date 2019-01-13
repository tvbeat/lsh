local sh = require 'lsh'

print('-- memfd --')
do
  local buf = '123'
  local memfd = sh.memfd(buf)
  assert(tostring(memfd) == '123')

  memfd:write('456789')
  assert(tostring(memfd) == '123456789')
  memfd:seek(0)
  memfd:write('foobar')
  assert(tostring(memfd) == 'foobar789')

  memfd:seek(6)
  local res = memfd:read()
  assert(res == '789')
  memfd:seek(0)
  local res = memfd:read()
  assert(res == 'foobar789')


end

print('-- memfd exec io --')

do
  local buf = 'hello'
  local res, err = sh.exec({'cat'}, {stdin  = sh.memfd(buf),
                                     stdout = sh.memfd()})
  assert(not err)
  res:wait()

  assert(tostring(res:stdout()) == buf)

end

print('-- memfd lines --')

do

  local buf = '123\n456\n567\nabc'
  local memfd = sh.memfd(buf)

  local count = 1
  for line in memfd:lines() do
    print(count)
    print(line, #line)
    count = count + 1
  end

  local buf = '123\r\n'
  local memfd = sh.memfd(buf)
  for line in memfd:lines() do
    print(line, #line)
  end

end

local path = require 'lsh.path'

local p = path('/etc')
print(p.path)
local p2 = p:join('resolv.conf')
print(p2.name)
print(p2.parent)
assert(p2.stem == 'resolv')
assert(p2.suffix == '.conf')
assert((p2:exists()))

local p3 = p2.parent
print(p3)
local p4 = p3.parent
print(p4)

local ok, err = p:chdir()
print(ok,err)

local pd = path(os.tmpname())
pd:unlink() -- remove tmp file
pd = pd:join('dir') -- add extra dir
local ok, err = pd:mkdir(nil, true) -- mkdir -p
print(ok, err)
print(pd)

pd:rmdir()
print(pd.parent)
local ok, err = pd.parent:rmdir()
print(ok, err)


assert(not pd:exists())
assert(not pd:is_dir())

do -- test stem
  assert(path('resolv.conf').stem == 'resolv')
  assert(path('lib.tar.gar').stem == 'lib.tar')
  assert(path('lib.tar').stem == 'lib')
  assert(path('lib').stem == 'lib')
  assert(path('/home/user/lib').stem == 'lib')
end

do -- test parent
  assert(path('/bla/z').parent == path('/bla'))
  assert(path('bla').parent == path('.'))
  assert(path('/bla').parent == path('/'))
end

do -- test parents
  local p = path('/usr/local/bin/lua')
  assert(p.parents[1] == path('/usr/local/bin'))
  assert(p.parents[2] == path('/usr/local'))
  assert(p.parents[3] == path('/usr'))
  assert(p.parents[4] == path('/'))

  p = path('dev/test')
  assert(p.parents[1] == path('dev'))
end

-- xattr
-- TODO: make sure they are run on fs with xattr enabled
--local px = path(os.tmpname())
--
--local ok ,err = px:setxattr('user.test', 123)
--print(err)
--local l, err = px:listxattr()
--print(l)
--for k,v in pairs(l) do print(k,v) end
--
--local ok, err = px:removexattr('user.test')
--print(ok,err)
--
--local res = px:getxattr('user.test')
--print(res)
--
--local ok, err = px:removexattr('user.test')
--print(ok,err)
--
--local ok, err = px:unlink()
--print(ok,err)

local path = require 'lsh1.path'

local p = path('/etc')
print(p.path)
local p2 = p:joinpath('resolv.conf')
print(p2.name)
print(p2.parent)
assert((p2:exists()))

local p3 = p2.parent
print(p3)
local p4 = p3.parent
print(p4)

local ok, err = p:chdir()
print(ok,err)

local pd = path(os.tmpname())
pd:unlink() -- remove tmp file
pd = pd:joinpath('dir') -- add extra dir
local ok, err = pd:mkdir(nil, true) -- mkdir -p
print(ok, err)
print(pd)

pd:rmdir()
print(pd.parent)
local ok, err = pd.parent:rmdir()
print(ok, err)


assert(not pd:exists())
assert(not pd:isdir())
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
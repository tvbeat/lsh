-- memfd - in memory anonymous file

local S = require 'syscall'

local fh     = require 'lsh.fio.fh'
local tablex = require 'lsh.tablex'

local _M = tablex.new(0, 8)
local memfd_mt = {
  __index = _M,
  __tostring = function(t)
    return tostring(t.fh)
  end,
}

function _M.new(buf, len)
  -- No need to worry about closing fd, it has close method assigned to __gc
  -- in ffi metatable (ljsyscall syscall/methods.lua#L152)
  local fd, err = S.memfd_create('', 'cloexec') -- TODO: sealing
  if err then
    return nil, tostring(err)
  end

  local memfd = setmetatable({fh = fh(fd)}, memfd_mt)

  if buf then
    memfd:write(buf, len)
  end

  return memfd
end

-- return 'memfd' if input is memfd type
function _M.type(self)
  if type(self) ~= 'table' then return nil end
  if getmetatable(self) == memfd_mt then
    return 'memfd'
  end

  return nil
end

function _M.close(self)
  return self.fh:close()
end

function _M.write(self, buf, len)
  return self.fh:write(buf, len)
end

function _M.read(self, buf, size)
  return self.fh:read(buf, size)
end

function _M.seek(self, position)
  return self.fh:seek(position)
end

function _M.lines(self)
  return self.fh:lines()
end

function _M.getfd(self)
  return self.fh:getfd()
end

local mt = {
  __index = _M,
  __call = function(t, buf, len)
    return _M.new(buf, len)
  end,
}

return setmetatable({}, mt)

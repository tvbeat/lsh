--- in-memory anonymous file
-- @module lsh.memfd

local S = require 'syscall'

local fh     = require 'lsh.fio.fh'
local tablex = require 'lsh.tablex'

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"

local _M = tablex.new(0, 8)
local memfd_mt = {
  __index = _M,
  __tostring = function(t)
    return tostring(t.fh)
  end,
}

--- create new @{memfd} instance
-- @tparam cdata buf TODO
-- @tparam int len TODO
-- @treturn[0] lsh.memfd new @{memfd} instance
-- @treturn[1] nil
-- @treturn[1] string error
function _M.new(buf, len)
  if buf and type(buf) ~= 'string' then
    error(err_str:format(1, 'new', 'string or nil', type(buf)), 2)
  end
  if len and type(len) ~= 'number' then
    error(err_str:format(2, 'new', 'number', type(len)), 2)
  end

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

--- return 'memfd' if input is memfd type
-- @tparam lsh.memfd self
-- @treturn[0] string `"memfd"`
-- @treturn[1] nil if the argument is not a @{memfd}
function _M.type(self)
  if type(self) ~= 'table' then return nil end
  if getmetatable(self) == memfd_mt then
    return 'memfd'
  end

  return nil
end

--- close file descriptor
-- @tparam lsh.memfd self
-- @return TODO
function _M.close(self)
  return self.fh:close()
end

--- write buffer to file descriptor
-- @tparam lsh.memfd self
-- @tparam string buf data to write
-- @tparam int len number of bytes to write
-- @return TODO
function _M.write(self, buf, len)
  return self.fh:write(buf, len)
end

--- read to buffer from file descriptor
-- @tparam lsh.memfd self
-- @tparam string buf buffer to hold data
-- @tparam int size maximum number of bytes to read
-- @return TODO
function _M.read(self, buf, size)
  return self.fh:read(buf, size)
end

--- seek file descriptor to position
-- @tparam lsh.memfd self
-- @tparam TODO position position to seek to
-- @return TODO
function _M.seek(self, position)
  return self.fh:seek(position)
end

--- return lines TODO
-- @tparam lsh.memfd self
-- @return TODO
function _M.lines(self)
  return self.fh:lines()
end

--- get file descriptor
-- @tparam lsh.memfd self
-- @return TODO
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

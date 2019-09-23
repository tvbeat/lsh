-- fio - file input/output

local S = require 'syscall'

local fh     = require 'lsh.fio.fh'
local tablex = require 'lsh.tablex'

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"

local _M = tablex.new(0, 1)

function _M.open(path, flags, mode)
  if type(path) ~= 'string' then
    error(err_str:format(1, 'open', 'string', type(path)), 2)
  end
  if type(flags) ~= 'table' then
    flags = { flags }
  end
  if type(mode) ~= 'table' then
    mode = { mode }
  end

  table.insert(flags, 'cloexec')

  -- No need to worry about closing fd, it has close method assigned to __gc
  -- in ffi metatable (ljsyscall syscall/methods.lua#L152)
  -- TODO
  local fd, err = S.open(path, table.concat(flags, ', '), table.concat(mode, ', '))
  if err then
    return nil, tostring(err)
  end

  return fh(fd)
end

return _M

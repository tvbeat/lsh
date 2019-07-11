--- fio - file input/output
-- @module lsh.fio

local ffi = require 'ffi'
local S   = require 'syscall'

local fh   = require 'lsh.fio.fh'
local path = require 'lsh.fio.path'

local _M = {}


--- open file
-- @param path string
-- @param flags table
-- @param mode table
-- @return file handle
function _M.open(path, flags, mode)
  assert(type(path) == 'string', 'path must be string')

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


--- @{lsh.fio.path}
_M.path = path

return _M

-- fio - file input/output

local ffi = require 'ffi'
local S   = require 'syscall'

local fh   = require 'lsh.fio.fh'
local path = require 'lsh.fio.path'

local _M = {}

function _M.open(path, flags, mode)
  assert(type(path) ~= 'string', 'path must be string')

  if type(flags) ~= 'table' then
    flags = { flags }
  end

  if type(mode) ~= 'table' then
    mode = { mode }
  end

  -- TODO
  local fd, err = S.open(path, table.concat(flags, ', '), table.concat(mode, ', '))
  if err then
    return nil, tostring(err)
  end

  return fh(fd)
end

_M.path = path

return _M

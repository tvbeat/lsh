--- File input/output.
-- @module lsh.fio

local S = require 'syscall'

local fh     = require 'lsh.fio.fh'
local libc   = require 'lsh.libc'
local tablex = require 'lsh.tablex'

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"

local _M = tablex.new(0, 1)

--[[- Opens the file at `path` with the given `flags` and `mode`.

This interface is not final. It will change in incompatible ways.

@function open
@tparam string path path to file
@tparam table flags flags
@tparam table mode mode
@treturn[1] lsh.fio.fh file handle
@treturn[2] nil
@treturn[2] string error
@usage
local sh = require 'lsh'

local fh = sh.open('/etc/hostname', 'rdonly')
]]
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

  -- TODO
  local fd, err = libc.retry_nofile(S.open, path, table.concat(flags, ', '), table.concat(mode, ', '))
  if err then
    return nil, tostring(err)
  end

  return fh.new(fd)
end

return _M

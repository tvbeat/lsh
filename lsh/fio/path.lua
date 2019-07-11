--- pathname manipulations
-- @module lsh.fio.path

local ffi = require 'ffi'
local S   = require 'syscall'

ffi.cdef[[
char *dirname(char *path);
]]

local C = ffi.C
local buf_t = ffi.typeof('char[?]')

local _M = {}

-- based on tarantool (2.1) src/lua/fio.lua
function _M.join(...)
  local i, path = 1, nil

  local len = select('#', ...)
  while i <= len do
    local sp = select(i, ...)
    assert(sp, "undefined path part "..i)

    sp = tostring(sp)
    if sp ~= '' then
      path = sp
      break
    else
      i = i + 1
    end
  end

  if path == nil then
    return '.'
  end

  i = i + 1
  while i <= len do
    local sp = select(i, ...)
    assert(sp, "undefined path part "..i)

    sp = tostring(sp)
    if sp ~= '' then
      path = path .. '/' .. sp
    end

    i = i + 1
  end

  path = path:gsub('/+', '/')
  if path ~= '/' then
    path = path:gsub('/$', '')
  end

  return path
end

-- based on tarantool (2.1) src/lua/fio.lua
function _M.abspath(path)
  assert(type(path) == 'string', 'path must be string')
  local joined_path = ''
  local path_tab = {}

  if string.sub(path, 1, 1) == '/' then
    joined_path = path
  else
    joined_path = _M.join(S.getcwd(), path)
  end

  for sp in string.gmatch(joined_path, '[^/]+') do
    if sp == '..' then
      table.remove(path_tab)
    elseif sp ~= '.' then
      table.insert(path_tab, sp)
    end
  end

  return '/' .. table.concat(path_tab, '/')
end

-- based on tarantool (2.1) src/lua/fio.lua
function _M.basename(path, suffix)
  assert(type(path) == 'string', 'path mast be string')

  path = string.gsub(path, '.*/', '')

  if suffix then
    suffix = tostring(suffix)
    assert(suffix, 'cannot convert suffix to string')

    if #suffix > 0 then
      suffix = string.gsub(suffix, '(.)', '[%1]')
      path = string.gsub(path, suffix, '')
    end
  end

  return path
end

-- based on tarantool (2.1) src/lua/fio.lua
function _M.dirname(path)
  assert(type(path) == 'string', 'path mast be string')
  path = buf_t(#path + 1, path)

  return ffi.string(C.dirname(path))
end

return _M

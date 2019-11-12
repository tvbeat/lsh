--- cmd utils
-- @module lsh.cmd.utils

local ffi = require 'ffi'
local S   = require 'syscall'

local tablex = require 'lsh.tablex'
local path   = require 'lsh.path'

ffi.cdef [[
int fileno(struct FILE* stream);
]]

local C = ffi.C

local _M = tablex.new(0, 2)

function _M.norm_arg(x)
  local x_type = type(x)

  if x_type == 'string' then
    return x
  elseif x_type == 'number' then
    return tostring(x)
  elseif x_type == 'table' then
    if x.type and x:type() == 'path' then
      return x
    end
  end

  return nil
end

local stdfd_obj_types = {
  fh =    true,
  path =  true,
}

function _M.norm_stdfd(x)
  local x_type = type(x)

  if x_type == 'string' then -- path to file
    local p, err = path.new(x)
    if err then return nil, err end
    return p
  elseif x_type == 'table' then -- path/fh/memfd
    local obj_type = x.type and x:type()
    if not stdfd_obj_types[obj_type] then
      return nil, 'table must be path/fh type'
    end
    -- TODO: check fh/memfd permissions
    return x
  elseif x_type == 'userdata' then -- lua file handle?
    -- allow only standard fds (0, 1, 2)
    local fd = tonumber(C.fileno(x))
    if fd == 0 then
      return nil, ("ambiguous redirect to fd %d"):format(fd)
    elseif fd == 1 then
      return S.stdout
    elseif fd == 2 then
      return S.stderr
    end
    return nil, ("invalid userdata fd %d"):format(fd)
  elseif x_type == 'cdata' then -- ljsyscall fd struct
    -- TODO: checks
    return x
  end

  return nil, ("invalid type %s"):format(x_type)
end

return _M

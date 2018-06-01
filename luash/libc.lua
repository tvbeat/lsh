local ffi   = require 'ffi'
local S = require "syscall"

ffi.cdef [[
  int execvp(const char *, const char* []);
]]

local C = ffi.C
local string_array = ffi.typeof("const char* [?]")

-- used for no return value, return true for use of assert
local function retbool(ret, err)
  if ret == -1 then return nil, error() end
  return true
end

local _M = {}

function _M.execvp(cmdname, args)
  local cargs = string_array(#args + 1, args or {})
  cargs[#args] = nil
  retbool(C.execvp(cmdname, cargs))
end

return _M

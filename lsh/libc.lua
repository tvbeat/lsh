local ffi   = require 'ffi'
local S = require "syscall"
local table_new = require 'table.new'

ffi.cdef [[
  int execvp(const char *, const char* []);

  typedef unsigned long size_t;

  typedef struct {
    size_t gl_pathc;
    char **gl_pathv;
    size_t gl_offs;
    int __dummy1;
    void *__dummy2[5];
  } glob_t;

  int  glob(const char *__restrict, int, int (*)(const char *, int), glob_t *__restrict);
  void globfree(glob_t *);
]]

local C = ffi.C
local string_array = ffi.typeof("const char* [?]")
local glob_t = ffi.typeof("glob_t[1]")

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

local glob_ret_codes = setmetatable({
  [1] = "GLOB_NOSPACE",
  [2] = "GLOB_ABORTED",
  [3] = "GLOB_NOMATCH",
  [4] = "GLOB_NOSYS",
}, {__index = "UNKNOWN_ERROR"})

function _M.glob(str)

  local results = ffi.new('glob_t[1]')
  -- TODO: handlers
  local ret = C.glob(str, 0, function(path, eerrno) print(path, eerrno) end, results)
  if ret ~= 0 then return nil, glob_ret_codes[ret] end

  local len = tonumber(results[0].gl_pathc)
  local res = table_new(len, 0)
  for i=0,len-1 do
    res[i+1] = ffi.string(results[0].gl_pathv[i])
  end

  C.globfree(results)

  return res
end

return _M

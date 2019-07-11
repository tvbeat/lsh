--- libc bindings
-- @module lsh.libc

local ffi = require 'ffi'
local S   = require 'syscall'

local tablex = require 'lsh.tablex'

ffi.cdef [[
  int execvp(const char *, const char* []);
  char *strerror(int errnum);

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
local string_array_t = ffi.typeof("const char *[?]")
local glob_t = ffi.typeof("glob_t[1]")

local function ffi_error()
  return ffi.string(C.strerror(ffi.errno()))
end

local _M = {}

local function arg_str(ar)
  if type(ar) == 'string' then
    return ar
  end

  local ar_len = #ar
  local ret = tablex.new(ar_len, 0)

  for i=1,ar_len do
    local p = ar[i]
    local p_type = type(ar)

    if p_type == 'table' then
      ret[i] = ("%s"):format(arg_str(p))
    else
      ret[i] = p
    end
  end

  return tablex.concat(ret, ' ')
end

--- execvp
-- @param cmdargs table
-- @return (result, error)
function _M.execvp(cmdargs)
  local cmdargs_len = #cmdargs
  local cargs = string_array_t(cmdargs_len + 1)

  -- normalize args to strings
  for i=1,cmdargs_len do
    cargs[i-1] = arg_str(cmdargs[i])
  end

  cargs[cmdargs_len] = nil

  local ret = C.execvp(cargs[0], cargs)
  return ret, ffi_error()
end

local glob_ret_codes = setmetatable({
  [1] = "GLOB_NOSPACE",
  [2] = "GLOB_ABORTED",
  [3] = "GLOB_NOMATCH",
  [4] = "GLOB_NOSYS",
}, {__index = "UNKNOWN_ERROR"})

local function glob_callback(path, eerrno)
  io.stderr:write(("glob error: %s %s"):format(path, eerrno))
end
local glob_callback_c = ffi.cast("int (*)(const char *, int)", glob_callback)

--- glob
-- @param str string
-- @return string
function _M.glob(str)
  if type(str) ~= 'string' then
    return nil, 'not a string'
  end

  local results = ffi.new('glob_t[1]')
  local ret = C.glob(str, 0, glob_callback_c, results)
  if ret ~= 0 then
    C.globfree(results)
    return nil, glob_ret_codes[ret]
  end

  local len = tonumber(results[0].gl_pathc)
  local res = tablex.new(len, 0)
  for i=0,len-1 do
    res[i+1] = ffi.string(results[0].gl_pathv[i])
  end

  C.globfree(results)

  return res
end

return _M

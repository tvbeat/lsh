--- libc bindings
-- @module lsh.libc

local ffi = require 'ffi'

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

local _M = tablex.new(0, 2)

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

  return table.concat(ret, ' ')
end

--- execvp
-- @param cmdargs TODO
-- @return TODO
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

local glob_errors = {}
local function glob_callback(path, eerrno)
  glob_errors[ffi.string(path)] = ffi_error(eerrno)
  return 0
end
local glob_callback_c = ffi.cast("int (*)(const char *, int)", glob_callback)

--[[- Glob the given path with pattern.
@function glob
@tparam string ppattern path pattern to match
@treturn[1] {string,...} array of paths instances
@treturn[1] table map of path keys and err string values (if any)
@treturn[2] nil
@treturn[2] string error message
]]
function _M.glob(ppattern)
  if type(ppattern) ~= 'string' then
    return nil, 'pattern must be string'
  end

  local results = glob_t()
  tablex.clear(glob_errors)
  local ret = C.glob(ppattern, 0, glob_callback_c, results)
  if ret ~= 0 then
    C.globfree(results)
    local err = glob_ret_codes[ret]
    if err == 'GLOB_NOMATCH' then
      return {}
    end

    return nil, err
  end

  local len = tonumber(results[0].gl_pathc)
  local res = tablex.new(len, 0)
  for i=0,len-1 do
    res[i+1] = ffi.string(results[0].gl_pathv[i])
  end

  C.globfree(results)

  local err_map
  if tablex.nkeys(glob_errors) > 0 then
    err_map = tablex.clone(glob_errors)
  end

  return res, err_map
end

return _M

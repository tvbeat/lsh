--- libc bindings
-- @module lsh.libc

local ffi = require 'ffi'

local tablex = require 'lsh.tablex'


ffi.cdef [[
  char *strerror(int errnum);
  void _exit(int status);
  // Function signature is modified to avoid casting step
  // ("const char*" -> "char *const").
  int execvpe(const char *file, const char*const [], const char*const []);

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

local _M = tablex.new(0, 3)

--[[- Terminates the process immediately, without flushing stdio buffers.
@tparam number status exit status
]]
function _M._exit(status)
  C._exit(status)
end

--[[- Executes the program with args and environment using execvpe.
@tparam string program program to execute
@tparam table args array of arguments
@tparam table envs map of environment variables
]]
function _M.execvpe(program, args, envs)
  -- cmd args
  local args_len = #args
  -- program + args_len
  local cargs_len = args_len + 1
  -- cargs array is starting at index zero, extra
  -- slot is needed for ending NULL
  local cargs = string_array_t(cargs_len + 1)
  cargs[0] = program -- push program
  for i=1,args_len do -- push args
    cargs[i] = tostring(args[i])
  end
  cargs[cargs_len] = nil -- NULL

  -- cmd environ
  local environ = {}
  local environ_len = 0
  for env, value in pairs(envs) do
    table.insert(environ, ("%s=%s"):format(env, value))
    environ_len = environ_len + 1
  end
  -- extra slot for holding NULL
  local cenviron = string_array_t(environ_len + 1, environ)
  cenviron[environ_len] = nil -- NULL

  -- finally do exec
  local ret = C.execvpe(program, cargs, cenviron)
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

--[[- Globs the given path pattern.
@function glob
@tparam string ppattern path pattern to match
@treturn[1] {string,...} array of paths
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

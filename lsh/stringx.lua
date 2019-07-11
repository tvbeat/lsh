--- stringx - extended string module
-- @module lsh.stringx

local ffi = require('ffi')

ffi.cdef[[
  const char *memmem(const char *haystack, size_t haystack_len,
                     const char *needle,   size_t needle_len);
  int isspace(int c);
]]

local c_char_ptr = ffi.typeof('const char *')

local memmem  = ffi.C.memmem
local isspace = ffi.C.isspace

local err_string_arg = "bad argument #%d to '%s' (%s expected, got %s)"

local function string_split_empty(inp, maxsplit)
  local p = c_char_ptr(inp)
  local p_end = p + #inp
  local rv = {}

  while true do
    -- skip the leading whitespaces
    while p < p_end and isspace(p[0]) ~= 0 do
      p = p + 1
    end
    if p == p_end then
      break
    end
    if maxsplit <= 0 then
      table.insert(rv, ffi.string(p, p_end - p))
      break
    end
    local chunk = p
    -- skip all non-whitespace characters
    while p < p_end and isspace(p[0]) == 0 do
      p = p + 1
    end
    assert((p - chunk) > 0)
    table.insert(rv, ffi.string(chunk, p - chunk))
    maxsplit = maxsplit - 1
  end

  return rv
end

local function string_split(inp, sep, maxsplit)
  local p = c_char_ptr(inp)
  local p_end = p + #inp
  local sep_len = #sep
  if sep_len == 0 then
    error(err_string_arg:format(2, 'string.split', 'non-empty string',
          "empty string"), 3)
  end
  local rv = {}

  while true do
    assert(p <= p_end)
    if maxsplit <= 0 or p == p_end then
      table.insert(rv, ffi.string(p, p_end - p))
      break
    end
    local chunk = p
    p = memmem(p, p_end - p, sep, sep_len)
    if p == nil then
      table.insert(rv, ffi.string(chunk, p_end - chunk))
      break
    end
    table.insert(rv, ffi.string(chunk, p - chunk))
    p = p + sep_len
    maxsplit = maxsplit - 1
  end

  return rv
end

local _M = string

--- split string at separator
-- based on tarantool (2.1): src/lua/string.lua
-- @param inp string
-- @param sep optional string
-- @param max optional int
-- @return table
function _M.split(inp, sep, max)
  if type(inp) ~= 'string' then
    error(err_string_arg:format(1, 'string.split', 'string', type(inp)), 2)
  end
  if sep ~= nil and type(sep) ~= 'string' then
    error(err_string_arg:format(2, 'string.split', 'string', type(sep)), 2)
  end
  if max ~= nil and (type(max) ~= 'number' or max < 0) then
    error(err_string_arg:format(3, 'string.split', 'positive integer',
                                type(max)), 2)
  end
  max = max or 0xffffffff

  if not sep then
    return string_split_empty(inp, max)
  end

  return string_split(inp, sep, max)
end

return _M

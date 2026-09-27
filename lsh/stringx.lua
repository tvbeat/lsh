--[[- String extensions.
@module lsh.stringx
]]

local ffi = require 'ffi'

local tablex = require 'lsh.tablex'

ffi.cdef[[
  const char *memmem(const char *haystack, size_t haystack_len,
                     const char *needle,   size_t needle_len);
  int isspace(int c);
]]

local c_char_ptr = ffi.typeof('const char *')

local memmem  = ffi.C.memmem
local isspace = ffi.C.isspace

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"

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
    error(err_str:format(2, 'split', 'non-empty string', 'empty string'), 3)
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

local _M = tablex.new(0, 2)

--[[- Splits a string by a separator.
@function split
@tparam string inp input string
@tparam[opt] string sep separator (default is whitespace)
@tparam[opt] int max maximum number of splits (default is unlimited)
@treturn {string,...} the pieces between separators
@usage
local sh = require 'lsh'

local parts = sh.stringx.split('a,b,c', ',', 1)
assert(parts[1] == 'a' and parts[2] == 'b,c')
]]
function _M.split(inp, sep, max)
  -- based on tarantool (2.1): src/lua/string.lua
  if type(inp) ~= 'string' then
    error(err_str:format(1, 'split', 'string', type(inp)), 2)
  end
  if sep ~= nil and type(sep) ~= 'string' then
    error(err_str:format(2, 'split', 'string', type(sep)), 2)
  end
  if max ~= nil and (type(max) ~= 'number' or max < 0) then
    error(err_str:format(3, 'split', 'positive integer', type(max)), 2)
  end
  max = max or 0xffffffff

  if not sep then
    return string_split_empty(inp, max)
  end

  return string_split(inp, sep, max)
end

--[[- Removes a final newline from a string.
@function chomp
@tparam string inp input string
@treturn string string without the final newline
]]
function _M.chomp(inp)
  if type(inp) ~= 'string' then
    error(err_str:format(1, 'chomp', 'string', type(inp)), 2)
  end

  return inp:gsub('\n$', '')
end

return _M

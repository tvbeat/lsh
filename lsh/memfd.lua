--- In-memory anonymous file.
-- @module lsh.memfd

local S = require 'syscall'

local fh     = require 'lsh.fio.fh'
local tablex = require 'lsh.tablex'

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"

local _M = tablex.new(0, 1)

--[[- Constructs a new in-memory anonymous file and returns
a handle to it.
@function new
@tparam[opt] cdata|string buf initial content of the new instance
@tparam[opt] int len length of the initial buffer (required if buf is `cdata`)
@treturn[1] lsh.fio.fh new @{fio.fh} instance
@treturn[2] nil
@treturn[2] string error
@usage
local sh = require 'lsh'

local fh = sh.memfd.new()
fh:write('abc')
fh:seek(0)
print(fh)
]]
function _M.new(buf, len)

  local fd, err = S.memfd_create('', 'cloexec')
  if err then
    return nil, tostring(err)
  end

  local fh_ = fh.new(fd)

  if buf then
    local buf_type = type(buf)
    if buf_type == 'cdata' then
      if type(len) ~= 'number' then
        error(err_str:format(2, 'new', 'number', type(len)), 2)
      end
    elseif buf_type ~= 'string' then
      error(err_str:format(1, 'new', 'string or cdata', type(buf)), 2)
    end

    fh_:write(buf, len)
  end

  return fh_
end

local mt = {
  __index = _M,
  --[[- Shorthand for `new`.
  @function __call
  @tparam table _M module table
  @tparam[opt] cdata|string buf initial content of the new instance
  @tparam[opt] int len length of the initial buffer (required if buf is `cdata`)
  @treturn[1] lsh.fio.fh new @{fio.fh} instance
  @treturn[2] nil
  @treturn[2] string error
  @usage
  local sh = require 'lsh'

  local fh = sh.memfd('abc')
  fh:seek(0)
  print(fh)
  ]]
  __call = function(t, buf, len)
    return _M.new(buf, len)
  end,
}

return setmetatable({}, mt)

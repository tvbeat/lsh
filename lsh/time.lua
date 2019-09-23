-- time - time and clock functions

local S = require 'syscall'

local tablex = require 'lsh.tablex'

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"

local _M = tablex.new(0, 1)

function _M.sleep(sec)
  if type(sec) ~= 'number' then
    error(err_str:format(1, 'sleep', 'number', type(sec)), 2)
  end

  local ok, err = S.sleep(sec)
  if err then
    return nil, tostring(err)
  end

  return ok
end

return _M

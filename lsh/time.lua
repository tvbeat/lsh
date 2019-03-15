-- time - time and clock functions

local S = require 'syscall'

local _M = {}

function _M.sleep(sec)
  assert(type(sec) == 'number', 'arg must be number')

  local ok, err = S.sleep(sec)
  if err then
    return nil, tostring(err)
  end

  return ok
end

return _M

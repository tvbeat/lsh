--- time and clock functions
-- @module lsh.time

local S = require 'syscall'

local _M = {}


--- sleep
-- @param seconds int
function _M.sleep(seconds)
  assert(type(seconds) == 'number', 'arg must be number')

  local ok, err = S.sleep(seconds)
  if err then
    return nil, tostring(err)
  end

  return ok
end

return _M

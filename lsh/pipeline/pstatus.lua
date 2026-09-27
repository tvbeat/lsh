--[[-- Describes the result of the child processes of a pipeline
after they have terminated.

This struct holds the exit statuses of the child processes.
The `run` method of @{lsh.pipeline} and the `wait` method of
@{lsh.pipeline.children} return it.

@module lsh.pipeline.pstatus
]]
local tablex = require 'lsh.tablex'

local status = require 'lsh.cmd.status'

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"

--- Status methods.
-- @section status
local methods = tablex.new(0, 3)

--[[- Returns the type of the instance.
@function type
@return the string `"pipeline_status"`
]]
function methods.type()
  return 'pipeline_status'
end

--[[- Returns `true` if all processes exited with status zero.

If a signal terminated a process, it returns `false`.

@function success
@tparam lsh.pipeline.pstatus self
@treturn bool
@usage
local sh = require 'lsh'

local status = sh.pipeline():add(sh.cmd('mkdir', 'projects'))
                            :run()
if status:success() then
  print('"projects/" directory created')
else
  print('failed to create "projects/" directory')
end
]]
function methods.success(self)
  for i=1,#self do
    if not self[i]:success() then
      return false
    end
  end

  return true
end

--[[- Returns the array of exit codes of the processes.

For each process, see @{lsh.cmd.status.code}.

@function codes
@tparam lsh.pipeline.pstatus self
@treturn {number,...} array of exit codes
@usage
local sh = require 'lsh'

local status = sh.pipeline():add(sh.cmd('ls'))
                            :add(sh.cmd('tail'))
                            :run()
for i, code in ipairs(status:codes()) do
  print(("Process %d exited with status code: %d"):format(i, code))
end
]]
function methods.codes(self)
  local len = #self
  local ret = tablex.new(len, 0)

  for i=1,len do
    ret[i] = self[i]:code()
  end

  return ret
end

local _M = tablex.new(0, 1)
local status_mt = {
  __index = methods,
  __tostring = function(_t)
    error('not implemented')
  end,
}

--- Functions
-- @section functions

--[[- Constructs a new `pstatus` instance.

You do not need to call this function directly.
Use @{lsh.pipeline.run} or @{lsh.pipeline.spawn}.

@tparam lsh.pipeline.children children instance
@tparam[opt] bool hang block until all processes exit
@treturn[1] lsh.pipeline.pstatus `pstatus`
@treturn[2] boolean `false` if a process did not exit yet
@treturn[3] nil
@treturn[3] string error message
]]
function _M.new(children, hang)
  if type(children) ~= 'table' then
    error(err_str:format(1, 'new', 'table', type(children)), 2)
  end
  if children._pstatus then -- already waited
    return children._pstatus
  end
  local len = #children

  local ret = {}
  for i=1,len do
    local st, err = status.new(children[i], hang)
    if err then return nil, err end
    if hang == false and not st then
      return false
    end

    ret[i] = st
  end

  local pstatus = setmetatable(ret, status_mt)
  children._pstatus = pstatus -- cache

  return pstatus
end

return _M

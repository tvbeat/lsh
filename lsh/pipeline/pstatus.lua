--[[-- Describes the result of a pipeline children processes after
they have terminated.

This struct is used to represent the exit statuses of a children processes.
Children processes are created via the @{lsh.pipeline} struct and their exit
statuses are exposed through the `run` method, or the `wait` method of
a @{lsh.pipeline.children} processes.

@module lsh.pipeline.pstatus
]]
local S = require 'syscall'
local tablex = require 'lsh.tablex'

local status = require 'lsh.cmd.status'

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"

--- Status methods.
-- @section status
local methods = tablex.new(0, 3)

--[[- Returns the type of a instance.
@function type
@return the string `"pipeline_status"`
]]
function methods.type()
  return 'pipeline_status'
end

--[[- Was termination successful?

Signal termination is not considered a success,
and success is defined as a zero exit status.

@function success
@tparam lsh.pipeline.pstatus self
@treturn bool
@usage
local sh = require 'lsh'

local status = sh.pipeline():add('mkdir'):arg('projects')
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

--[[- Returns the array of exit codes of the processes, if any.

It will return `nil` if the processes were terminated by a signal.

@function codes
@tparam lsh.pipeline.pstatus self
@treturn[1] number
@treturn[2] nil
@usage
local sh = require 'lsh'

local status = sh.cmd('mkdir'):arg('projects')
                              :run()
local code = status:code()
if code then
  print(("Exited with status code: %d"):format(code))
else
  print('Process terminated by signal')
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
  __tostring = function(t)
    error('not implemented')
  end,
}

--- Functions
-- @section functions

--[[- Constructs the new `pstatus` instance.

There is no need to use this method directly, see @{lsh.pipeline.run} and
@{lsh.pipeline.spawn} for practical program execution.

@tparam lsh.pipeline.children children instance
@tparam[opt] bool hang hang by default
@treturn[1] lsh.pipeline.pstatus `pstatus`
@treturn[2] boolean false if process didn't terminate
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

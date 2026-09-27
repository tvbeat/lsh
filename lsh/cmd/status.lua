--[[-- Describes the result of a process after it has terminated.

This struct holds the exit status of a child process.
The `run` method of @{lsh.cmd} and the `wait` method of
@{lsh.cmd.child} return it.

@module lsh.cmd.status
]]
local S = require 'syscall'
local tablex = require 'lsh.tablex'

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"

--- Status methods.
-- @section status
local methods = tablex.new(0, 3)

--[[- Returns the type of the instance.
@function type
@tparam lsh.cmd.status self
@return the string `"cmd_status"`
@usage
local sh = require 'lsh'

assert(sh.cmd('ls'):run():type() == 'cmd_status')
]]
function methods.type()
  return 'cmd_status'
end

--[[- Returns `true` if the process exited with status zero.

If a signal terminated the process, it returns `false`.

@function success
@tparam lsh.cmd.status self
@treturn bool
@usage
local sh = require 'lsh'

local status = sh.cmd('mkdir'):arg('projects')
                              :run()
if status:success() then
  print('"projects/" directory created')
else
  print('failed to create "projects/" directory')
end
]]
function methods.success(self)
  local exit_status = self.infop.status
  if exit_status then
    return exit_status == 0
  end

  return false
end

--[[- Returns the exit code of the process, if any.

If a signal terminated the process, it returns the signal number.

@function code
@tparam lsh.cmd.status self
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
function methods.code(self)
  return self.infop.status
end

--- Functions
-- @section functions
local _M = tablex.new(0, 1)
local status_mt = {
  __index = methods,
  __tostring = function(t)
    return tostring(t.infop.status)
  end,
}

--[[- Constructs a new `status` instance.

You do not need to call this function directly.
Use @{lsh.cmd.run} or @{lsh.cmd.spawn}.

@tparam lsh.cmd.child child child instance
@tparam[opt] bool hang block until the process exits (`false` by default)
@treturn[1] lsh.cmd.status `status`
@treturn[2] boolean `false` if the process did not exit yet
@treturn[3] nil
@treturn[3] string error message
]]
function _M.new(child, hang)
  if type(child) ~= 'table' then
    error(err_str:format(1, 'new', 'number', type(child)), 2)
  end
  if child._status then -- already waited
    return child._status
  end

  local options = 'exited'
  if not hang then
    options = ("%s, nohang"):format(options)
  end

  local infop, err = S.waitid('pid', child._pid, options)
  if not infop then
    return nil, tostring(err)
  end

  if infop.code == 0 then
    return false
  end

  local status = setmetatable({infop = infop}, status_mt)
  child._status = status -- cache the status

  return status
end

return _M

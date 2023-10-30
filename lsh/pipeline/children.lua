--[[- Representation of a running or exited pipeline's children processes.
@module lsh.pipeline.children
]]

local S = require 'syscall'

local child  = require 'lsh.cmd.child'
local tablex = require 'lsh.tablex'

local pstatus = require 'lsh.pipeline.pstatus'

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"

local function spawn_pipeline(pl)
  local pl_len = #pl
  local children = tablex.new(pl_len, 0)

  local cur_stdin
  for i=1,pl_len do
    local next_stdin, cur_stdout

    if i ~= pl_len then
      local status, err
      status, err, next_stdin, cur_stdout = S.pipe()
      assert(status, err)
    end

    local cmd = pl[i]:clone()

    if cur_stdin then
      cmd._stdin = cur_stdin
    elseif pl._stdin then
      cmd._stdin = pl._stdin
    end

    if cur_stdout then
      cmd._stdout = cur_stdout
    elseif pl._stdout then
      cmd._stdout = pl._stdout
    end

    -- todo: does it make sense ?
    if pl._stderr then cmd._stderr = pl._stderr end

    children[i] = child.new(cmd, false)

    if cur_stdin then
      S.close(cur_stdin)
      cur_stdin = nil
    end

    if next_stdin then
      cur_stdin = next_stdin
    end

    if cur_stdout then
      S.close(cur_stdout)
    end
  end

  return children
end

-- children --
--
-- {
--   -- array of children instances
-- }
--

--- Children methods.
-- @section children
local methods = tablex.new(0, 6)

--[[- Returns the instance type.
@function type
@return the string `"children"`
]]
function methods.type()
  return 'children'
end

--[[- Send a signal to all child processes.

See: @{lsh.cmd.child.kill}

@function kill
@tparam lsh.pipeline.children self
@tparam[opt] string signal signal name
@treturn[1] bool signal status
@treturn[1] string error message
@usage
local sh = require 'lsh'

local children = sh.pipeline():add('sleep', 10):spawn()
child:kill()
]]
function methods.kill(self, signal)
  if type(signal) ~= 'string' then
    error(err_str:format(2, 'signal', 'string', type(signal)), 2)
  end

  for i=1,#self do
    local ok, err = self[i]:kill(signal)
    if not ok then
      return nil, err
    end
  end

  return true
end

--[[- Returns the array of OS-assigned process identifiers
of all child processes.

@function ids
@tparam lsh.pipeline.children self
@treturn table array of process identifiers
]]
function methods.ids(self)
  error('not implemented')
end

--[[- Waits for all child proceses to exit completely, returning
the `pstatus` that it exited with.

This function will continue to have the same return value
after it has been called at least once.

@function wait
@tparam lsh.pipeline.children self
@treturn lsh.pipeline.pstatus @{pstatus} struct
]]
function methods.wait(self)
  local st, err = pstatus.new(self, true)
  if err then
    return nil, err
  end

  return st
end

--[[- Attempts to collect the exit statuses of the
child processes if they have already exited.

This function will not block the calling thread and will
only check to see if the child processes have exited or not.
If the child processes have exited then process IDs are reaped.
This function is guaranteed to repeatedly return a successful
exit status so long as the child processes have already exited.

If all child processes have exited, then @{pstatus} is returned.
If the exit statuses are not available at this time then `false` is
returned.

@function try_wait
@tparam lsh.pipeline.children self
@treturn[1] lsh.pipeline.pstatus @{pstatus} struct
@treturn[2] false
@treturn[3] nil
@treturn[3] err
]]
function methods.try_wait(self)
  local st, err = pstatus.new(self, false)
  if err then
    return nil, err
  end

  return st
end

--[[- Simultaneously waits for all child processes to exit and
collect all remaining output on the stdout/stderr handles,
returning an `output` struct.

By default, stdin, stdout and stderr are inherited from the parent.
In order to capture the output into `output` it is necessary to create
new `memfd` instances between parent and child. Use `stdout(sh.memfd())`
or `stderr(sh.memfd())`, respectively.

@function wait_with_output
@tparam lsh.pipeline.children self
@treturn[1] lsh.cmd.children.output @{output} struct
@treturn[2] nil
@treturn[2] err
]]
function methods.wait_with_output(self)
  local _pstatus, err = self:wait()
  if err then
    return nil, err
  end

  --[[- The output of a finished process.

  This is returned by either the @{pipeline.output} method,
  or the `wait_with_output` method of a `children` instance.

  @within Output
  @field stdout stdout of `pipeline` instance (if any)
  @field stderr stderr of `pipeline` instance (if any)
  @field status `pstatus` struct
  @table output
  ]]
  local output = {
    stdout = self[#self]._cmd._stdout,
    stderr = self[1]._cmd._stderr,
    status = _pstatus
  }

  return output
end

--- Functions
-- @section functions
local _M = tablex.new(0, 1)
local children_mt = {
  __index = methods,
  __tostring = function(t)
    local len = #t
    local ret = tablex.new(len, 0)

    for i=1,len do
      ret[i] = tostring(t[i])
    end

    return table.concat(ret, '\n')
  end,
}

--[[- Constructs the new `children` handle struct from
`cmd`s defined in `pipeline` instance and executes it.

Input `cmd` is cloned and contained inside `child` instance
to be available for introspection.

There is no need to use this method directly, see @{lsh.pipeline.run} and
@{lsh.pipeline.spawn} for practical program execution.

@tparam lsh.pipeline pl
@treturn lsh.pipeline.children `children`
]]
function _M.new(pl)
  if type(pl) ~= 'table' or not pl.type or not pl:type() == 'pipeline' then
    error(err_str:format(1, 'new', 'pipeline object', type(pl)), 2)
  end
  if #pl == 0 then return nil, 'pipeline is empty' end

  local children = spawn_pipeline(pl)

  return setmetatable(children, children_mt)
end

return _M

--[[-- Representation of a running or exited child process.

Use this module to manage child processes. A @{lsh.cmd} instance
holds the configuration of the process and spawns the child.

### Example
```lua
local sh = require 'lsh'

local child, err = sh.cmd('cat'):arg('file.txt')
                                :spawn()
if err then error('failed to execute child') end

local ecode, err = child:wait()
if err then error('failed to wait on child') end

assert(ecode:success())
```

@module lsh.cmd.child
]]
local S = require 'syscall'

local libc   = require 'lsh.libc'
local tablex = require 'lsh.tablex'
local path   = require 'lsh.path'

local status = require 'lsh.cmd.status'

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"

local mode_urwgror = {'RUSR', 'WUSR', 'RGRP', 'ROTH'}
local flags_cwt = {'creat', 'wronly', 'trunc'}

local function child_stdin(stdin)
  local stdin_type = type(stdin)
  if stdin_type == 'table' then
    if stdin:type() == 'path' then
      local fh, err = stdin:open('rdonly', 'RUSR')
      if err then
        io.stderr:write(err..'\n')
        os.exit(1)
      end
      stdin = fh
    end
    S.dup2(stdin:getfd(), S.stdin)
    stdin:close()
  elseif stdin ~= S.stdin then
    S.dup2(stdin, S.stdin)
    S.close(stdin)
  end
end

local function child_stdout(stdout)
  local stdout_type = type(stdout)
  if stdout_type == 'table' then
    if stdout:type() == 'path' then
      local fh, err = stdout:open(flags_cwt, mode_urwgror)
      if err then
        io.stderr:write(err..'\n')
        os.exit(1)
      end
      stdout = fh
    end
    S.dup2(stdout:getfd(), S.stdout)
    stdout:close()
  elseif stdout ~= S.stdout then
    S.dup2(stdout, S.stdout)
    if stdout ~= S.stderr then -- don't close stderr
      S.close(stdout)
    end
  end
end

local function child_stderr(stderr)
  local stderr_type = type(stderr)
  if stderr_type == 'table' then
    if stderr:type() == 'path' then
      local fh, err = stderr:open(flags_cwt, mode_urwgror)
      if err then
        io.stderr:write(err..'\n')
        os.exit(1)
      end
      stderr = fh
    end
    S.dup2(stderr:getfd(), S.stderr)
    stderr:close()
  elseif stderr ~= S.stderr then
    S.dup2(stderr, S.stderr)
    if stderr ~= S.stdout then -- don't close stdout
      S.close(stderr)
    end
  end
end

local function child_workdir(path)
  local ok, err = path:chdir()
  if not ok then
    error(("unable to change child workdir: %s"):format(err), 0)
  end
end

-- TODO: portability, currently it only works on linux
-- with mounted /proc
-- reference: https://github.com/openssh/openssh-portable/blob/master/openbsd-compat/bsd-closefrom.c
local function fd_close_from(lowfd)
  local proc_fd_dir = path('/proc', S.getpid(), 'fd')
  if not proc_fd_dir:is_dir() then
    error('/proc is not mounted')
  end
  local _, dir_obj = proc_fd_dir:lsdir()
  local dir_fd = dir_obj.fd:getfd()
  while true do
    local dent = dir_obj:next()
    if not dent then break end
    local fd = tonumber(dent)
    if fd >= lowfd and fd ~= dir_fd then
      S.close(fd)
    end
  end
end

local function exec_cmd(cmd)
  local pid = S.fork()

  if pid == 0 then
    -- the forked child must never return into the parent's Lua code
    local _, err = pcall(function()
      if cmd._workdir then child_workdir(cmd._workdir) end

      if cmd._stdin  then child_stdin(cmd._stdin)  end
      if cmd._stdout then child_stdout(cmd._stdout) end
      if cmd._stderr then child_stderr(cmd._stderr) end

      fd_close_from(3)

      -- if the parent dies, the children die
      S.prctl("set_pdeathsig", "kill")

      local _, err = libc.execvpe(cmd._program, cmd._args, cmd._envs)
      error("exec: "..err, 0)
    end)
    io.stderr:write(("%s: %s\n"):format(cmd._program, tostring(err)))
    io.stderr:flush()
    S.exit(127)
  end

  return pid
end

-- child --
--
-- {
--   _cmd    -- cmd struct
--   _pid    -- number
--   _status -- status struct
-- }

--- Child methods.
-- @section child
local methods = tablex.new(0, 6)

--[[- Returns the instance type.
@function type
@return the string `"child"`
@usage
local sh = require 'lsh'

assert(sh.cmd('ls'):spawn():type() == 'child')
]]
function methods.type()
  return 'child'
end

--[[- Sends a signal to the child process.

If you do not give a signal, it sends `SIGKILL` (`kill`),
which forces the child process to exit.

Valid signals: `hup int quit ill trap abrt bus fpe kill
usr1 segv usr2 pipe alrm term stkflt chld cont stop tstp
ttin ttou urg xcpu xfsz vtalrm prof winch io pwr sys`

@function kill
@tparam lsh.cmd.child self
@tparam[opt] string signal signal name
@treturn[1] boolean `true`
@treturn[2] nil
@treturn[2] string error message
@usage
local sh = require 'lsh'

local child = sh.cmd('sleep', 10):spawn()
child:kill()
]]
function methods.kill(self, signal)
  if signal and type(signal) ~= 'string' then
    error(err_str:format(2, 'signal', 'string', type(signal)), 2)
  end

  signal = signal or 'kill'
  -- see: https://github.com/justincormack/ljsyscall/blob/master/syscall/linux/constants.lua#L339
  local ok, err = S.kill(self._pid, signal)
  if not ok then
    return nil, tostring(err)
  end

  return ok
end

--[[- Returns the OS-assigned process identifier
associated with this child.

@function id
@tparam lsh.cmd.child self
@treturn number process identifier
@usage
local sh = require 'lsh'

local child = sh.cmd('ls'):spawn()
child:id()
]]
function methods.id(self)
  return self._pid
end

--[[- Waits for the child to exit completely, returning
the `status` that it exited with.

After the first call, this function always returns the same value.

@function wait
@tparam lsh.cmd.child self
@treturn lsh.cmd.status @{status} struct
@usage
local sh = require 'lsh'

local child = sh.cmd('ls'):spawn()
child:wait()
]]
function methods.wait(self)
  local st, err = status.new(self, true)
  if err then
    return nil, err
  end

  return st
end

--[[- Attempts to collect the exit status of the
child if it has already exited.

This function does not block the calling thread. It only
checks if the child process exited.

If the child exited, it reaps the process ID and returns @{status}.
Later calls return the same @{status}.
If the exit status is not available yet, it returns `false`.

@function try_wait
@tparam lsh.cmd.child self
@treturn[1] lsh.cmd.status @{status} struct
@treturn[2] false
@treturn[3] nil
@treturn[3] string error message
@usage
local sh = require 'lsh'

local child = sh.cmd('ls'):spawn()
child:try_wait()
]]
function methods.try_wait(self)
  local st, err = status.new(self, false)
  if err then
    return nil, err
  end

  return st
end

--[[- Waits for the child to exit and returns an `output` struct
with the stdout and stderr handles of the child.

By default, stdin, stdout and stderr are inherited from the parent.
To capture the output in `output`, set a `memfd` instance
with `stdout(sh.memfd())` or `stderr(sh.memfd())`.

@function wait_with_output
@tparam lsh.cmd.child self
@treturn[1] lsh.cmd.child.output @{output} struct
@treturn[2] nil
@treturn[2] string error message
@usage
local sh = require 'lsh'

local child, err = sh.cmd('cat'):arg('file.txt')
                                :stdout(sh.memfd())
                                :spawn()
if not child then error(err) end

local output, err = child:wait_with_output()
if not output then error(err) end
assert(output.status:success())
-- read output line by line
for line in output.stdout:lines() do
  print(line)
end
]]
function methods.wait_with_output(self)
  local _status, err = self:wait()
  if err then
    return nil, err
  end

  --[[- The output of a finished process.

  The @{cmd.output} method and the @{wait_with_output} method
  of a child process return this table.

  @within Output
  @field stdout stdout of `cmd` instance (if any)
  @field stderr stderr of `cmd` instance (if any)
  @field status `status` struct
  @table output
  ]]
  local output = {
    stdout = self._cmd._stdout,
    stderr = self._cmd._stderr,
    status = _status
  }

  return output
end

--- Functions
-- @section functions
local _M = tablex.new(0, 1)
local child_mt = {
  __index = methods,
  __tostring = function(self)
    return string.format('"%s" -> %s', self._cmd, self._pid)
  end,
}

--[[- Constructs a new `child` instance and runs the program
defined in `cmd`.

You do not need to call this function directly.
Use @{cmd.run} or @{cmd.spawn}.

@tparam lsh.cmd cmd
@tparam[opt] boolean clone control cloning of input cmd (`true` by default)
@treturn lsh.cmd.child new @{child} instance
@usage
local sh = require 'lsh'

local child = require 'lsh.cmd.child'

child.new(sh.cmd('echo', 1))
]]
function _M.new(cmd, clone)
  if type(cmd) ~= 'table' or not cmd.type or not cmd:type() == 'cmd' then
    error(err_str:format(1, 'new', 'cmd', type(cmd)), 2)
  end

  local _cmd
  if clone == false then
    _cmd = cmd
  else
    _cmd = cmd:clone()
  end
  local _pid = exec_cmd(_cmd)

  return setmetatable({_cmd = _cmd, _pid = _pid}, child_mt)
end

return _M

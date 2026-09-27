--[[- A process builder. It controls how lsh spawns a new process.

`cmd.new(program)` makes a default configuration, where `program`
is the name or path of the program to run. Use the builder methods
to change the configuration (for example, to add arguments) before
you spawn the process:
```lua
local cmd = require 'lsh.cmd'

local output, err = cmd('sh'):arg('-c')
                             :arg('echo hello')
                             :output()
if err then error('failed to execute process') end

local hello = tostring(output.stdout)
```

You can use one command to spawn multiple processes. The builder
methods change the command, but they do not spawn a process.
```lua
local cmd = require 'lsh.cmd'

local echo_hello = cmd('sh')
echo_hello:arg('-c')
          :arg('echo hello')

local hello_1, err = echo_hello:output()
if err then error('failed to execute process') end

local hello_2, err = echo_hello:output()
if err then error('failed to execute process') end
```

You can also call builder methods after you spawn a process,
and then spawn a new process with the changed configuration.
```lua
local cmd = require 'lsh.cmd'

local list_dir = cmd('ls')

-- Execute `ls` in the current directory of the program.
local status, err = list_dir:run()
if err then error('failed to execute process') end

-- Change `ls` to execute in the root directory.
list_dir:workdir('/')

-- And then execute `ls` again but in the root directory.
local status, err = list_dir:run()
if err then error('failed to execute process') end
```

Use the slash (`/`) operator to chain commands into a @{pipeline}.
```lua
local cmd = require 'lsh.cmd'

local ls = cmd('ls'):workdir('/')
local tail = cmd('tail')

local pl = ls / tail:arg('-n1')
local status, err = pl:run()
if err then error('failed to execute pipeline processes') end
```

@module lsh.cmd
]]

local S = require 'syscall'

local tablex   = require 'lsh.tablex'
local path     = require 'lsh.path'
local pipeline = require 'lsh.pipeline'
local memfd    = require 'lsh.memfd'

local child   = require 'lsh.cmd.child'

local norm_arg   = require('lsh.cmd.utils').norm_arg
local norm_stdfd = require('lsh.cmd.utils').norm_stdfd

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"
local err_tbl_str = "bad argument #%d at index #%d to '%s' (%s expected, got %s)"

-- cmd --
--
-- {
--   _program -- program name or path
--   _args    -- array of program arguments
-- }
--

--- Cmd methods.
-- @section cmd
local methods = tablex.new(0, 14)

--[[- Returns the type of the object.
@function type
@tparam lsh.cmd self
@return the string `"cmd"`
@usage
local sh = require 'lsh'

assert(sh.cmd('ls'):type() == 'cmd')
]]
function methods.type()
  return 'cmd'
end

--[[- Clones the cmd instance.
@function clone
@tparam lsh.cmd self
@treturn lsh.cmd new @{cmd} instance, clone of `self`
@usage
local sh = require 'lsh'

local c1 = sh.cmd('ls')
local c2 = c1:clone()
]]
function methods.clone(self)
  return tablex.clone(self, true)
end

--[[- Executes a command as a child process,
waiting for it to finish and collecting its exit status.

By default, stdin, stdout and stderr are inherited from the parent.

@function run
@tparam lsh.cmd self
@treturn lsh.cmd.status @{cmd.status}
@usage
local sh = require 'lsh'

local status = sh.cmd('ls'):run()
]]
function methods.run(self)
  return child.new(self):wait()
end

--[[- Executes the command as a child process, returning a handle to it.

By default, stdin, stdout and stderr are inherited from the parent.

@function spawn
@tparam lsh.cmd self
@treturn lsh.cmd.child `child`
@usage
local sh = require 'lsh'

local child = sh.cmd('ls'):spawn()
local status = child:wait()
]]
function methods.spawn(self)
  return child.new(self)
end

--[[- Executes the command as a child process, waiting for
it to finish and collecting all of its output.

By default, the output captures stdout and stderr in `memfd` instances.

@function output
@tparam lsh.cmd self
@treturn lsh.cmd.child.output @{cmd.child.output}
@usage
local sh = require 'lsh'

local output, err = sh.cmd('cat'):arg('file.txt')
                                 :output()
if not output then error(err) end
print(("status: %s"):format(output.status))
for line in output.stdout:lines() do
  print(line)
end
for line in output.stderr:lines() do
  io.stderr:write(line, '\n')
end

assert(output.status:success())
]]
function methods.output(self)
  local _cmd = self:clone()
  if not _cmd._stdout then
    _cmd:stdout(memfd.new())
  end
  if not _cmd._stderr then
    _cmd:stderr(memfd.new())
  end

  return child.new(_cmd, false):wait_with_output()
end

--[[- Adds an argument to pass to the program.

Pass one argument per call.

To pass multiple arguments, see `args`.

@function arg
@tparam lsh.cmd self
@tparam string|number|lsh.path arg program argument
@treturn lsh.cmd `self`
@usage
local sh = require 'lsh'

sh.cmd('ls'):arg('-a')
            :run()
]]
function methods.arg(self, arg)
  local res = norm_arg(arg)
  if not res then
    error(err_str:format(2, 'arg',
      'string or number or lsh.path',
      type(arg)), 2)
  end
  table.insert(self._args, res)

  return self
end

--[[- Adds multiple arguments to pass to the program.

To pass one argument, see `arg`.

@function args
@tparam lsh.cmd self
@tparam table args array of program arguments
@treturn lsh.cmd `self`
@usage
local sh = require 'lsh'

sh.cmd('ls'):args({'-a', '-l'})
            :run()
]]
function methods.args(self, args)
  if type(args) ~= 'table' then
    error(err_str:format(2, 'args', 'table', type(args)), 2)
  end
  for i=1,#args do
    local arg = norm_arg(args[i])
    if not arg then
      error(err_tbl_str:format(2, i, 'args',
        'string or number or lsh.path',
        type(args[i]), 2))
    end
    table.insert(self._args, arg)
  end

  return self
end

--[[- Sets or updates the working directory for the child process.
@function workdir
@tparam lsh.cmd self
@tparam string|lsh.path wd working directory
@treturn lsh.cmd `self`
@usage
local sh = require 'lsh'

sh.cmd('ls'):workdir('/bin')
            :run()
]]
function methods.workdir(self, wd)
  if not wd or wd == '' then
    self._workdir = nil
    return self
  end

  local p, err = path.new(wd)
  if err then return nil, err end
  self._workdir = p

  return self
end

--[[- Adds or updates multiple environment variable mappings.
@function env
@tparam lsh.cmd self
@tparam table envs name/value pairs of environment variables
@treturn lsh.cmd `self`
@usage
local sh = require 'lsh'

sh.cmd('ls'):env({PATH = '/bin'})
            :run()
]]
function methods.env(self, envs)
  if type(envs) ~= 'table' then
    error(err_str:format(2, 'env', 'table', type(envs)), 2)
  end
  for env, val in pairs(envs) do
    self._envs[env] = tostring(val)
  end

  return self
end

--[[- Removes an environment variable mapping.
@function env_remove
@tparam lsh.cmd self
@tparam string env environment variable
@treturn lsh.cmd `self`
@usage
local sh = require 'lsh'

sh.cmd('ls'):env_remove('PATH')
            :run()
]]
function methods.env_remove(self, env)
  if type(env) ~= 'string' then
    error(err_str:format(2, 'env', 'string', type(env)), 2)
  end
  self._envs[env] = nil

  return self
end

--[[- Clears the entire environment map for the child process.
@function env_clear
@tparam lsh.cmd self
@treturn lsh.cmd `self`
@usage
local sh = require 'lsh'

sh.cmd('ls'):env_clear()
            :run()
]]
function methods.env_clear(self)
  self._envs = {}

  return self
end

--[[- Sets or unsets the child process's standard
input (stdin) handle.
@function stdin
@param self @{cmd}
@tparam[opt] string|userdata|lsh.fio.fh|lsh.path val handle
value
@treturn lsh.cmd `self`
@usage
local sh = require 'lsh'

sh.cmd('tail'):stdin('/path/to/file')
              :run()
]]
function methods.stdin(self, val)
  if not val then
    self._stdin = nil
    return self
  end

  local res, err = norm_stdfd(val)
  if err then error(err, 2) end
  self._stdin = res

  return self
end

--[[- Sets or unsets the child process's standard
output (stdout) handle.
@function stdout
@param self @{cmd}
@tparam[opt] string|userdata|lsh.fio.fh|lsh.path val handle
value
@treturn lsh.cmd `self`
@usage
local sh = require 'lsh'

sh.cmd('echo', 1):stdout('/dev/null')
                 :run()
]]
function methods.stdout(self, val)
  if not val then
    self._stdout = nil
    return self
  end

  local res, err = norm_stdfd(val)
  if err then error(err, 2) end
  self._stdout = res

  return self
end

--[[- Sets or unsets the child process's standard
error (stderr) handle.
@function stderr
@param self @{cmd}
@tparam[opt] string|userdata|lsh.fio.fh|lsh.path val handle
value
@treturn lsh.cmd `self`
@usage
local sh = require 'lsh'

sh.cmd('echo', 1):stderr(io.stdout)
                 :run()
]]
function methods.stderr(self, val)
  if not val then
    self._stderr = nil
    return self
  end

  local res, err = norm_stdfd(val)
  if err then error(err, 2) end
  self._stderr = res

  return self
end

local cmd_mt = {
  __index = methods,
  __tostring = function(t)
    local args_len = #t._args
    local res = tablex.new(args_len + 1, 0)
    table.insert(res, t._program)
    for i=1,args_len do
      table.insert(res, tostring(t._args[i]))
    end

    return table.concat(res, ' ')
  end,
   --[[- Constructs a pipeline from two @{cmd} instances.
   @function __div
   @tparam lsh.cmd l left @{cmd}
   @tparam lsh.cmd r right @{cmd}
   @treturn lsh.pipeline new @{pipeline} instance
   @usage
   local sh = require 'lsh'

   local p = sh.cmd('ls') /
             sh.cmd('rev')
   p:run()
   ]]
  __div = function(l, r)
    assert(l:type() == 'cmd')
    assert(r:type() == 'cmd')
    return pipeline():add(l):add(r)
  end,
}

--- Functions
-- @section functions
local _M = tablex.new(0, 1)

--[[- Constructs a new @{cmd} for launching the `program`
with optional arguments.

The new cmd uses this default configuration:

- Inherit the environment of the current process.
- Inherit the working directory of the current process.
- Inherit stdin, stdout and stderr.

If `program` does not contain a slash, lsh searches `PATH` for it.

@function new
@tparam string program program name or path to program
@tparam[opt] string|number|lsh.path ... program arguments
@treturn lsh.cmd new @{cmd} instance
@usage
local sh = require 'lsh'

sh.cmd.new('echo', 1):run()
]]
function _M.new(program, ...)
  if type(program) ~= 'string' then
    error(err_str:format(1, 'new', 'string', type(program)), 2)
  end
  local args_len = select('#', ...)
  local cmd = {
    _program = program,
    _args = tablex.new(args_len, 0),
    _envs = S.environ(), -- returns env/value pairs
    _workdir = path.cwd()
  }

  -- optional args
  for i=1,args_len do
    local arg = select(i, ...)
    if arg then
      local res = norm_arg(arg)
      if not res then
        error(err_str:format(i+1, 'new',
          'string or number or lsh.path',
          type(arg)), 2)
      end
      table.insert(cmd._args, res)
    end
  end

  return setmetatable(cmd, cmd_mt)
end

local mt = {
  --[[- Shorthand for `new`.
  @function __call
  @tparam table _M module table
  @tparam string program program name or path to program
  @tparam[opt] string|number|lsh.path ... program arguments
  @treturn lsh.cmd new @{cmd} instance
  @usage
  local sh = require 'lsh'

  sh.cmd('echo', 1):run()
  ]]
  __call = function(_M, program, ...)
    return _M.new(program, ...)
  end,
}

return setmetatable(_M, mt)

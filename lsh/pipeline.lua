--[[- A pipeline builder. It controls how lsh spawns processes
that are connected with pipes.
@module lsh.pipeline
]]

local tablex = require 'lsh.tablex'
local path   = require 'lsh.path'
local memfd  = require 'lsh.memfd'

local children  = require 'lsh.pipeline.children'

local norm_stdfd = require('lsh.cmd.utils').norm_stdfd

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"

-- pipeline --
--
-- {
--   -- array of cmd structs
-- }
--

--- Pipeline methods.
-- @section pipeline
local methods = tablex.new(0, 10)

--[[- Returns the type of the instance.
@function type
@return the string `"pipeline"`
@usage
local sh = require 'lsh'

assert(sh.pipeline():type() == 'pipeline')
]]
function methods.type()
  return 'pipeline'
end

--[[- Clones the pipeline instance.
@function clone
@tparam lsh.pipeline self
@treturn lsh.pipeline new @{pipeline} struct, clone of `self`
@usage
local sh = require 'lsh'

local p1 = sh.pipeline():add(sh.cmd('ls'))
local p2 = p1:clone()
]]
function methods.clone(self)
  return tablex.clone(self, true)
end

--[[- Adds a @{cmd} instance to the pipeline.

The pipeline stores a clone of the `cmd` instance.

@function add
@tparam lsh.pipeline self
@tparam lsh.cmd cmd `cmd` instance
@treturn lsh.pipeline `self`
@usage
local sh = require 'lsh'

local echo1 = sh.cmd('echo', 1)
sh.pipeline():add(echo1)
             :run()
]]
function methods.add(self, cmd)
  if type(cmd) == 'table' and cmd.type and cmd:type() == 'cmd' then
    table.insert(self, cmd:clone())
    return self
  end

  error(err_str:format(2, 'add', 'table', type(cmd)), 2)
end

--[[- Executes the `cmd`s in the `pipeline` as `children` processes,
waiting for them to finish and collecting their exit statuses.

By default, stdin, stdout and stderr are inherited from the parent.

@function run
@tparam lsh.pipeline self
@treturn lsh.pipeline.pstatus `pipeline.pstatus`
@usage
local sh = require 'lsh'

local status = sh.pipeline():add(sh.cmd('ls'))
                            :add(sh.cmd('tail'))
                            :run()
]]
function methods.run(self)
  return children.new(self):wait()
end

--[[- Executes the `cmd`s in the `pipeline` as `children` processes,
waiting for them to finish and collecting all of their output.

By default, the output captures stdout and stderr in `memfd` instances.

@function output
@tparam lsh.pipeline self
@treturn lsh.pipeline.children.output @{pipeline.children.output}
]]
function methods.output(self)
  local pl = self:clone()
  if not pl._stdout then
    pl:stdout(memfd.new())
  end
  if not pl._stdout then
    pl:stderr(memfd.new())
  end

  return children.new(pl):wait_with_output()
end

--[[- Executes the `cmd`s in the `pipeline` as `children` processes,
returning a handle to them.

By default, stdin, stdout and stderr are inherited from the parent.

@function spawn
@tparam lsh.pipeline self
@treturn lsh.pipeline.children `pipeline.children`
@usage
local sh = require 'lsh'

local children = sh.pipeline():add(sh.cmd('ls'))
                              :add(sh.cmd('tail'))
                              :spawn()
local status = children:wait()
]]
function methods.spawn(self)
  return children.new(self)
end

--[[- Sets or updates the working directory for the
child processes.
@function workdir
@tparam lsh.pipeline self
@tparam string|lsh.path wd working directory
@treturn lsh.pipeline `self`
@usage
local sh = require 'lsh'

sh.pipeline():workdir('/bin')
             :add(sh.cmd('ls'))
             :add(sh.cmd('tail'))
             :run()
]]
function methods.workdir(self, wd)
  if not wd or wd == '' then
    self._workdir = nil
    return self
  end

  local p, err = path(wd)
  if err then return nil, err end
  self._workdir = p

  return self
end

--[[- Sets or unsets the standard input (stdin) handle of the pipeline.
@function stdin
@param self @{pipeline}
@tparam[opt] string|userdata|lsh.fio.fh|lsh.path val handle
value
@treturn lsh.pipeline `self`
@usage
local sh = require 'lsh'

sh.pipeline():add(sh.cmd('tail', '-n1'))
             :add(sh.cmd('rev'))
             :stdin('/path/to/file')
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

--[[- Sets or unsets the standard output (stdout) handle of the pipeline.
@function stdout
@param self @{pipeline}
@tparam[opt] string|userdata|lsh.fio.fh|lsh.path val handle
value
@treturn lsh.pipeline `self`
@usage
local sh = require 'lsh'

sh.pipeline():add(sh.cmd('ls', '-l'))
             :add(sh.cmd('rev'))
             :stdout('/dev/null')
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

--[[- Sets or unsets the standard error (stderr) handle of the pipeline.
@function stderr
@param self @{pipeline}
@tparam[opt] string|userdata|lsh.fio.fh|lsh.path val handle
value
@treturn lsh.pipeline `self`
@usage
local sh = require 'lsh'

sh.pipeline():add(sh.cmd('ls', 'nonexistentfile'))
             :add(sh.cmd('rev'))
             :stderr(io.stdout)
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

local pipeline_mt = {
  __index = methods,
  __tostring = function(t)
    local len = #t
    local ret = tablex.new(len, 0)

    for i=1,len do
      ret[i] = string.format('%s', t[i])
    end

    return table.concat(ret, ' | ')
  end,
   --[[- Adds a @{cmd} instance to the pipeline.
   @function __div
   @tparam lsh.pipeline l left @{pipeline}
   @tparam lsh.cmd r right @{cmd}
   @treturn lsh.pipeline @{pipeline} instance
   @usage
   local sh = require 'lsh'

   local p = sh.pipeline() /
             sh.cmd('ls') /
             sh.cmd('tail')
   p:run()
   ]]
  __div = function(l, r)
    assert(l:type() == 'pipeline')
    assert(r:type() == 'cmd')
    return l:add(r)
  end,
}

--- Functions
-- @section functions
local _M = tablex.new(0, 1)

--[[- Constructs a new @{pipeline} instance.
@treturn lsh.pipeline new @{pipeline} instance
@usage
local sh = require 'lsh'

sh.pipeline.new():add(sh.cmd('echo', 123))
                 :add(sh.cmd('rev'))
                 :run()
]]
function _M.new()
  return setmetatable({}, pipeline_mt)
end

local mt = {
  __index = _M,
  --[[- Shorthand for `new`.
  @tparam table _M module table
  @treturn lsh.pipeline new @{pipeline} struct
  @usage
  local sh = require 'lsh'

  sh.pipeline():add(sh.cmd('echo', 123))
               :add(sh.cmd('rev'))
               :run()
  ]]
  __call = function(_M)
    return _M.new()
  end,
}

return setmetatable(_M, mt)

--[[- A pipeline builder, providing fine-grained control over
how new piped processes should be spawned.
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

--[[- Returns the type of a instance.
@function type
@return the string `"pipeline"`
@usage
local sh = require 'lsh'

assert(sh.cmd('ls'):type() == 'cmd')
]]
function methods.type()
  return 'pipeline'
end

--[[- Clones pipeline instance.
@function clone
@tparam lsh.pipeline self
@treturn lsh.pipeline new @{pipeline} struct, clone of `self`
@usage
local sh = require 'lsh'

local p1 = sh.pipeline():add('ls')
local p2 = p1:clone()
]]
function methods.clone(self)
  return tablex.clone(self, true)
end

--[[- Adds @{cmd} instance into pipeline.

`cmd` instance will be cloned before inserting into
`pipeline`.

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

--[[- Executes `cmd`s in a `pipeline` as a `children` processes,
waiting for it to finish and collecting its exit statuses.

By default, stdin, stdout and stderr are inherited from the parent.

@function run
@tparam lsh.pipeline self
@treturn lsh.pipeline.pstatus `pipeline.pstatus`
@usage
local sh = require 'lsh'

local status = sh.pipeline():add('ls')
                            :add('tail')
                            :run()
]]
function methods.run(self)
  return children.new(self):wait()
end

--[[- Executes the command as a child processes, waiting for
it to finish and collecting all of its output.

By default, stdout and stderr are captured using `memfd` (and used
to provide the resulting output)

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

--[[- Executes the `cmd`s in a `pipeline` as a `children` processes,
returning a handle to it.

By default, stdin, stdout and stderr are inherited from the parent.

@function spawn
@tparam lsh.pipeline self
@treturn lsh.pipeline.children `pipeline.children`
@usage
local sh = require 'lsh'

local children = sh.pipeline():add('ls')
                              :add('tail')
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
             :add('ls')
             :add('tail')
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

--[[- Sets or unsets the pipeline standard input (stdin) handle.
@function stdin
@param self @{pipeline}
@tparam[opt] string|userdata|lsh.fio.fh|lsh.path val handle
value
@treturn lsh.pipeline `self`
@usage
local sh = require 'lsh'

sh.pipeline():add('tail', '-n1')
             :add('rev')
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

--[[- Sets or unsets the pipeline standard output (stdout) handle.
@function stdout
@param self @{pipeline}
@tparam[opt] string|userdata|lsh.fio.fh|lsh.path val handle
value
@treturn lsh.pipeline `self`
@usage
local sh = require 'lsh'

sh.pipeline():add('ls', '-l')
             :add('rev')
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

--[[- Sets or unsets the pipeline standard error (stderr) handle.
@function stderr
@param self @{pipeline}
@tparam[opt] string|userdata|lsh.fio.fh|lsh.path val handle
value
@treturn lsh.pipeline `self`
@usage
local sh = require 'lsh'

sh.pipeline():add('ls', 'nonexistentfile')
             :add('rev')
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
   --[[- Adds @{cmd} instance to pipeline.
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

sh.pipeline.new():add('echo', 123)
                 :add('rev')
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

  sh.pipeline():add('echo', 123)
               :add('rev')
               :run()
  ]]
  __call = function(_M)
    return _M.new()
  end,
}

return setmetatable(_M, mt)

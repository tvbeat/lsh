--- command pipeline
-- @module lsh.pipeline

local S = require 'syscall'

local cmd    = require 'lsh.cmd'
local tablex = require 'lsh.tablex'
local execs  = require 'lsh.pipeline.execs'

-- pipeline --
--
-- {
--   -- array of cmd type objects
-- }
--

local methods = tablex.new(0, 10)

--- clone
-- @tparam lsh.pipeline self
-- @treturn lsh.pipeline new @{pipeline} instance, clone of `self`
function methods.clone(self)
  return tablex.clone(self, true)
end

--- return `"pipeline"`
-- @treturn string `"pipeline"`
function methods.type()
  return 'pipeline'
end

--- add command to pipeline
-- @tparam lsh.pipeline self
-- @param ... @(lsh.cmd) or arguments to @(lsh.cmd) TODO
-- @treturn lsh.pipeline `self` with added stage
function methods.add(self, ...)
  -- check if first argument is cmd object
  local len = select('#', ...)
  if len == 1 then
    local x = select(1, ...)
    if not x then return nil, 'no args provided' end
    if type(x) == 'table' and x.type and x:type() == 'cmd' then
      table.insert(self, x:clone())
      return self
    end
  end

  -- construct cmd from args
  local cmd_, err = cmd(...)
  if err then return nil, err end
  table.insert(self, cmd_)

  return self
end

-- run the pipeline (`exec` and `wait`)
-- @tparam lsh.pipeline self
-- @treturn lsh.pipeline.execs TODO
function methods.run(self)
  return execs(self):wait()
end

-- start executing the pipeline. you need to @{wait} for it to finish to get the result
-- @tparam lsh.pipeline self
-- @treturn lsh.pipeline.execs TODO
function methods.exec(self)
  return execs(self)
end

local _M = tablex.new(0, 2)
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
  __call = function(t)
    return t:exec()
  end,
}

-- create new ${pipeline} instance
-- @treturn lsh.pipeline new @{pipeline} instance
function _M.new()
  return setmetatable({}, pipeline_mt)
end

--- return `"pipeline"` if input is of @{pipeline} type
-- @param tbl
-- @treturn[0] string `"pipeline"` if the argument is a @{pipeline}
-- @treturn[1] nil otherwise
function _M.type(tbl)
  if type(tbl) ~= 'table' then return nil end
  local is_pipeline = getmetatable(tbl) == pipeline_mt
  if is_pipeline then
    return 'pipeline'
  end

  return nil
end

local mt = {
  __index = _M,
  __call = function(_)
    return _M.new()
  end,
}

return setmetatable(_M, mt)

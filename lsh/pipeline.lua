local S      = require 'syscall'
local exec   = require 'lsh.exec'
local tablex = require 'lsh.tablex'

local string = string

local function exec_pipeline(execs)
  local execs_len = #execs
  local in_

  for i=1,execs_len do
    local r, w

    if i ~= execs_len then
      local status, err
      status, err, r, w = S.pipe()
    end

    execs[i]:set_opt({
        stdin  = in_,
        stdout = w
      })()

    if _in then
      S.close(_in)
    end

    if i ~= execs_len then
      S.close(w)
    end

    in_ = r
  end

  return execs
end

-- pipeline --
--
-- {
--   execs -- array of exec type struct
-- }
--

local _M = {}
local pipeline_mt = {
  __index = _M,
  __tostring = function(t)
    local len = #t.execs
    local ret = tablex.new(len, 0)

    for i=1,len do
      tablex.insert(ret, string.format('%s', t.execs[i]))
    end

    return tablex.concat(ret, '\n')
  end,
  __call = function(t, o)
    return t:exec(o)
  end,
}

function _M.new()
  return setmetatable({execs = {}}, pipeline_mt)
end

function _M.clone(self)
  local execs_old = self.execs
  assert(execs_old)

  local p = _M.new()

  for i=1,#execs_old do
    p:add(execs_old[i])
  end

  return p
end

function _M.add(self, c, o)
  local c_type = type(c)
  assert(c_type == 'table' or c_type == 'function',
         'first arg must be table or function')
  if o then
    assert(type(o) == 'table', 'second arg must be table')
  end

  local exec_
  if exec.type(c) then -- exec type
    exec_ = c:clone(o)
  else -- cmd type or command table/function
    exec_ = exec.new(c, o)
  end

  tablex.insert(self.execs, exec_)

  return self
end

function _M.exec(self, o)
  local exec_ = self.execs[1] -- take the first one
  if not exec_ then return nil, 'nothing to execute' end
  if exec_.pid then return nil, 'already executed'   end

  -- TODO: handle opt
  exec_pipeline(self.execs)

  return self
end

function _M.wait(self)
  local execs = self.execs
  local execs_len = #execs
  local exit_statuses = tablex.new(execs_len, 0)

  for i=1,execs_len do
    exit_statuses[i] = execs[i]:wait().exit_status
  end

  self.exit_statuses = exit_statuses

  return self
end

-- TODO: return nice metatable
function _M.status(self, wait)
  local execs = self.execs
  local execs_len = #execs
  local alive = false

  local ret = tablex.new(execs_len, 1)
  for i=1,execs_len do
    local status = execs[i]:status(wait)
    if not alive and status.alive then
      alive = true
    end
    ret[i] = status
  end

  ret.alive = alive

  return ret
end

local mt = {
  __index = _M,
  __call = function(t)
    return _M.new()
  end,
}

return setmetatable({}, mt)

local S = require 'syscall'

local exec   = require 'lsh.cmd.exec'
local tablex = require 'lsh.tablex'

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"

local function exec_pipeline(pl)
  local pl_len = #pl
  local in_
  local execs = tablex.new(pl_len, 0)

  for i=1,pl_len do
    local r, w

    if i ~= pl_len then
      local status, err
      status, err, r, w = S.pipe()
    end

    -- Use exec module directly to skip
    -- double cloning of cmd object.
    local pe = exec.new(pl[i])
    if in_ then pe.cmd:stdin(in_) end
    if w   then pe.cmd:stdout(w) end
    execs[i] = pe()

    if in_ then
      S.close(in_)
    end

    if i ~= pl_len then
      S.close(w)
    end

    in_ = r
  end

  return execs
end

-- execs --
--
-- {
--   exec -- array of exec type objects
-- }
--
local methods = tablex.new(0, 2)
local attrs = tablex.new(0, 4)

function attrs.stdin(execs)
  return execs[1]:stdin()
end

function attrs.stdout(execs)
  return execs[#execs]:stdout()
end

function attrs.stderr(execs)
  return execs[#execs]:stderr()
end

-- TODO: return nice metatable
function attrs.status(execs)
  local execs_len = #execs
  local alive = false

  local ret = tablex.new(execs_len, 1)
  for i=1,execs_len do
    local status = execs[i].status
    if not alive and status.alive then
      alive = true
    end
    ret[i] = status
  end

  ret.alive = alive

  return ret
end

-- return "execs"
function methods.type()
  return 'execs'
end

function methods.wait(self)
  local execs_len = #self
  local exit_statuses = tablex.new(execs_len, 0)

  for i=1,execs_len do
    exit_statuses[i] = self[i]:wait().exit_status
  end

  self.exit_statuses = exit_statuses

  return self
end

local _M = tablex.new(0, 2)
local execs_mt = {
  __index = function (t, k)
    if attrs[k] then
      return attrs[k](t)
    end

    return methods[k]
  end,
  __tostring = function(t)
    local len = #t
    local ret = tablex.new(len, 0)

    for i=1,len do
      ret[i] = tostring(t[i])
    end

    return table.concat(ret, '\n')
  end,
}

function _M.new(pl)
  if type(pl) ~= 'table' or not pl.type or not pl:type() == 'pipeline' then
    error(err_str:format(1, 'new', 'pipeline object', type(pl)), 2)
  end
  if #pl == 0 then return nil, 'nothing to exec' end

  local execs = exec_pipeline(pl)

  return setmetatable(execs, execs_mt)
end

-- return "execs" if input is execs type
function _M.type(tbl)
  if type(tbl) ~= 'table' then return nil end
  if getmetatable(tbl) == execs_mt then
    return 'execs'
  end

  return nil
end

local mt = {
  __call = function(_, pl)
    return _M.new(pl)
  end,
}

return setmetatable(_M, mt)

-- exec structure
local S      = require 'syscall'

local cmd    = require 'lsh.cmd'
local libc   = require 'lsh.libc'
local tablex = require 'lsh.tablex'

local function child_fds(cmd_opt)
  local stdin  = cmd_opt.stdin
  local stdout = cmd_opt.stdout
  local stderr = cmd_opt.stderr

  if stdin then
    if type(stdin) == "string" then
      --TODO: check open
      local fd = S.open(stdin, 'rdonly', 'RUSR')
      S.dup2(fd, S.stdin)
      S.close(fd)
    elseif stdin ~= S.stdin then
      S.dup2(stdin, S.stdin)
      S.close(stdin)
    end
  end

  if stdout then
    if type(stdout) == "string" then
      local fd = S.open(stdout, 'creat, wronly, trunc', 'RUSR, WUSR')
      S.dup2(fd, S.stdout)
      S.close(fd)
    elseif stdout ~= S.stdout then
      S.dup2(stdout, S.stdout)
      if stdout ~= S.stderr then -- don't close stderr
        S.close(stdout)
      end
    end
  end

  if stderr then
    if type(stderr) == "string" then
      local fd = S.open(stderr, 'creat, wronly, trunc', 'RUSR, WUSR')
      S.dup2(fd, S.stderr)
      S.close(fd)
    elseif stderr ~= S.stderr then
      S.dup2(stderr, S.stderr)
      if stderr ~= S.stdout then -- don't close stdout
        S.close(stderr)
      end
    end
  end
end

local function child_env(envs)
  for env, v in pairs(envs) do
    S.setenv(env, v, true)
  end
end

local function child_workdir(path)
  -- write checks
  S.chdir(path)
end

local function exec_cmd(cmd)
  local pid = S.fork()

  if pid == 0 then
    local opt = cmd.opt
    local c = opt.noglob and cmd.cmd or cmd:glob()

    if opt.env then child_env(opt.env) end
    if opt.workdir then child_workdir(opt.workdir) end

    child_fds(opt)

    -- if the parent dies, the children die
    S.prctl("set_pdeathsig", "kill")

    local _, err = libc.execvp(c)
    error("exec: "..err)
  end

  return pid
end

-- TODO: naive implementation
local function exec_fun(cmd)
  local pid = S.fork()

  if pid == 0 then
    local fn  = cmd.cmd
    local opt = cmd.opt

    if opt.env then child_env(opt.env) end
    if opt.workdir then child_workdir(opt.workdir) end

    child_fds(opt)

    S.prctl("set_pdeathsig", "kill")

    fn()
    os.exit(0)
  end

  return pid
end

-- exec --
--
-- {
--   cmd         -- cmd type struct
--   pid         -- number
--   exit_status -- number
-- }
--
local _M = {}
local exec_mt = {
  __index = _M,
  __tostring = function(t)
      local es = t.exit_status or '?'
      return string.format('"%s" -> %s', t.cmd, es)
    end,
  __call = function(t)
      local pid
      local cmd_ = t.cmd

      local _, etype = cmd_:type()
      if etype == 'table' then
        pid = exec_cmd(cmd_)
      else
        pid = exec_fun(cmd_)
      end
      t.pid = pid

      return t
    end,
}

function _M.new(c, o)
  local c_type = type(c)
  assert(c_type == 'table' or c_type == 'function',
         'first arg must be table or function')
  if o then
    assert(type(o) == 'table', 'second arg must be table')
  end

  local cmd_, err
  if c_type == 'table' and c.type and c:type() == 'cmd' then
    cmd_ = c -- just point
  else -- command table/function
    cmd_, err = cmd(c, o)
  end

  if err then
    return nil, err
  end

  return setmetatable({cmd = cmd_}, exec_mt)
end

function _M.clone(self, o)
  assert(self)
  local cmd_ = self.cmd:clone()
  cmd_:set_opt(o) -- override options table

  return _M.new(cmd_)
end

-- return "exec" if input is exec type
function _M.type(self)
  if type(self) ~= 'table' then return false end
  if getmetatable(self) == exec_mt then
    return 'exec'
  end

  return false
end

function _M.wait(self)
  local pid = self.pid
  if not pid then return nil end

  if self.exit_status then -- already waited
    return nil
  end

  local infop = S.waitid('pid', pid, 'exited')

  local exit_status = infop and infop.status or nil
  if not exit_status then return nil end

  self.exit_status = exit_status

  return self
end

-- TODO: return nice metatable
function _M.status(self, wait)
  local pid = self.pid
  if not pid then return nil end
  local alive       = false
  local exit_status = self.exit_status

  if exit_status then -- already waited
    return {
      pid         = pid,
      alive       = alive,
      exit_status = exit_status,
    }
  end

  local options = {'exited', 'nohang'}
  if not wait then
    tablex.insert(options, 'nowait')
  end

  local infop = S.waitid('pid', pid, tablex.concat(options, ', '))

  if infop then
    alive = infop.code == 0 or false
    exit_status = infop.status
  end

  -- pereserve exit_status only when child exited and waited
  if wait and exit_status and not alive then
    self.exit_status = exit_status
  end

  return {
    pid         = pid,
    alive       = alive,
    exit_status = exit_status,
  }
end

function _M.set_opt(self, o)
  if type(o) ~= 'table' then return nil end
  self.cmd:set_opt(o)

  return self
end

local mt = {
  __index = _M,
  __call = function(_, c, o)
    local res, err = _M.new(c, o)
    if err then return nil, err end
    return res()
  end,
}

return setmetatable({}, mt)

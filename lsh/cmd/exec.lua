-- exec structure
local S = require 'syscall'

local libc   = require 'lsh.libc'
local tablex = require 'lsh.tablex'
local path   = require 'lsh.path'

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"

local function child_stdin(stdin)
  local stdin_type = type(stdin)
  if stdin_type == 'table' then -- fh/memfd/path
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
  if stdout_type == 'table' then -- fh/memfd/path
    if stdout:type() == 'path' then
      local fh, err = stdout:open({'creat', 'wronly', 'trunc'}, {'RUSR', 'WUSR'})
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
  if stderr_type == 'table' then -- fh/memfd/path
    if stderr:type() == 'path' then
      local fh, err = stderr:open({'creat', 'wronly', 'trunc'}, {'RUSR', 'WUSR'})
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

local function child_env(envs)
  for env, v in pairs(envs) do
    S.setenv(env, v, true)
  end
end

local function child_workdir(path)
  local ok, err = path:chdir()
  if not ok then
    error(("unable to change child workdir: %s"):format(err))
  end
end

-- glob cmd
-- When cmd workdir is set function needs to change working
-- directory to get correct globbing result and restore
-- it back to original cwd.
-- returns new cmd object
local function glob_cmd(cmd)
  local cmd_globbed = cmd:clone()
  local workdir = cmd._workdir
  local index = 1
  local cwd

  if workdir then
    local cwd_ = path.cwd()
    if workdir ~= cwd then
      cwd = cwd_
      local ok, err = workdir:chdir()
      if not ok then
        error(("unable to change workdir: %s"):format(err))
      end
    end
  end

  for i=1,#cmd do
    local p = cmd[i]
    if type(p) == 'table' then -- glob only first level
      cmd_globbed[index] = p
      index = index + 1
    else
      local res, err = libc.glob(p)
      if err then -- skip glob error
        cmd_globbed[index] = p
        index = index + 1
      else
        for y=1,#res do
          cmd_globbed[index] = res[y]
          index = index + 1
        end
      end
    end
  end

  -- restore working directory
  if cwd then
    local ok, err = cwd:chdir()
    if not ok then
      error(("unable to restore workdir: %s"):format(err))
    end
  end

  return cmd_globbed
end

local function exec_cmd(cmd)
  local pid = S.fork()

  if pid == 0 then
    if cmd._env     then child_env(cmd._env) end
    if cmd._workdir then child_workdir(cmd._workdir) end

    if cmd._stdin  then child_stdin(cmd._stdin)  end
    if cmd._stdout then child_stdout(cmd._stdout) end
    if cmd._stderr then child_stderr(cmd._stderr) end

    -- if the parent dies, the children die
    S.prctl("set_pdeathsig", "kill")

    local _, err = libc.execvp(cmd)
    error("exec: "..err)
  end

  return pid
end

-- exec --
--
-- {
--   cmd         -- cmd type object
--   pid         -- number
--   exit_status -- number
-- }
--
local methods = tablex.new(0, 2)
local attrs = tablex.new(0, 4)

function attrs.stdin(exec)
  return exec.cmd._stdin
end

function attrs.stdout(exec)
  return exec.cmd._stdout
end

function attrs.stderr(exec)
  return exec.cmd._stderr
end

-- TODO: return nice metatable
function attrs.status(self)
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

  local infop = S.waitid('pid', pid, 'exited, nohang, nowait')

  if infop then
    alive = infop.code == 0 or false
    exit_status = infop.status
  end

  return {
    pid         = pid,
    alive       = alive,
    exit_status = exit_status,
  }
end

-- return "exec"
function methods.type()
  return 'exec'
end

function methods.wait(self)
  local pid = self.pid
  if not pid then return nil end

  if self.exit_status then -- already waited
    return self
  end

  local infop = S.waitid('pid', pid, 'exited')

  local exit_status = infop and infop.status or nil
  if not exit_status then return nil end

  self.exit_status = exit_status

  return self
end

local _M = tablex.new(0, 2)
local exec_mt = {
  __index = function (t, k)
    if attrs[k] then
      return attrs[k](t)
    end

    return methods[k]
  end,
  __tostring = function(t)
    local es = t.exit_status or '?'
    return string.format('"%s" -> %s', t.cmd, es)
  end,
  __call = function(t)
    t.pid = exec_cmd(t.cmd)
    return t
  end,
}

function _M.new(cmd)
  if type(cmd) ~= 'table' or not cmd.type or not cmd:type() == 'cmd' then
    error(err_str:format(1, 'new', 'cmd object', type(cmd)), 2)
  end

  -- apply globbing if needed
  local cmd_
  if not cmd._glob then
    cmd_ = cmd:clone()
  else
    cmd_= glob_cmd(cmd)
  end

  return setmetatable({cmd = cmd_}, exec_mt)
end

-- return "exec" if input is exec type
function _M.type(tbl)
  if type(tbl) ~= 'table' then return nil end
  if getmetatable(tbl) == exec_mt then
    return 'exec'
  end

  return nil
end

local mt = {
  __call = function(_, cmd)
    local res = _M.new(cmd)
    return res()
  end,
}

return setmetatable(_M, mt)

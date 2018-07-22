local S    = require 'syscall'
local libc = require 'lsh.libc'

local table_new = require 'table.new'
local table = table

local function redr_stdfds(in_, out_, err_)
  if in_ and in_ ~= S.stdin then
    S.dup2(in_, S.stdin)
    S.close(in_)
  end

  if out_ and out_ ~= S.stdout then
    S.dup2(out_, S.stdout)
    S.close(out_)
  end

  if err_ and err_ ~= S.stderr then
    S.dup2(err_, S.stderr)
    S.close(err_)
  end
end

local function child_env(envs)
  for env, v in pairs(envs) do
    S.setenv(env, v, true)
  end
end

local function glob_cmd(cmd)
  local cmd_len = #cmd
  local cmd_globbed = table_new(cmd_len, 0)

  for i=1,cmd_len do
    local cmd_part = cmd[i]
    local res, err = libc.glob(cmd_part)

    if err then
      table.insert(cmd_globbed, cmd_part)
    else
      for y=1,#res do table.insert(cmd_globbed, res[y]) end
    end
  end

  return cmd_globbed
end

local function exec_proc(cmd, in_, out_, err_)
  local pid = S.fork()

  if pid == 0 then
    local opt = cmd._opt
    local c = opt.noglob and cmd or glob_cmd(cmd)

    if opt.env then child_env(opt.env) end
    redr_stdfds(in_, out_, err_)

    local ret = libc.execvp(c[1], c)
    error("execvp failed with: ", ret)
    os.exit(1)
  end

  return pid
end

local function exec_fun(fpck, in_, out_, err_)
  local pid = S.fork()

  if pid == 0 then
    local fn = fpck[1]
    local opt = fpck._opt

    if opt.env then child_env(opt.env) end
    redr_stdfds(in_, out_, err_)

    fn()
    os.exit(0)
  end

  return pid
end

local function pipes(cmds)
  local cmds_len = #cmds
  local pids     = table_new(cmds_len, 0)

  local in_ = S.stdin

  for i=1,cmds_len do
    local r1, w1

    if i == cmds_len then
      w1 = S.stdout
      r1 = S.stdin
    else
      local status, err
      status, err, r1, w1 = S.pipe()
    end

    local pid = cmds[i](in_, w1)
    pids[i] = pid

    if i ~= cmds_len then
      S.close(w1)
    end

    in_ = r1
  end

  return pids
end

local function wait(pid)
  local r, err, status = S.waitpid(pid, "ALL")
  -- TODO: normalize, handle
  local exit_status = status and status.status or nil
  return exit_status
end


local _M = {}

-- cmd --

local cmd_ = {}

function cmd_.new(cmd, opt)
  if not cmd then return error("missing cmd") end
  local cmd_type = type(cmd)

  if cmd_type == "function" then
    local fpck = {
      [1] = cmd,
      _opt = opt or {},
    }

    return setmetatable(fpck, {
      __tostring = function(t)
        return tostring(t[1])
      end,
      __call = function(t, in_, out_, err_)
        local pid = exec_fun(t, in_, out_, err_)
        t.pid = pid
        return pid
      end
    })
  elseif cmd_type == "table" then
    cmd._opt = opt or {}

    return setmetatable(cmd, {
      __tostring = function(t)
        return table.concat(t, ' ')
      end,
      __call = function(t, in_, out_, err_)
        local pid = exec_proc(t, in_, out_, err_)
        t.pid = pid
        return pid
      end
    })
  end

  return error("unknown cmd type")
end

-- exec --

local exec = {}

local exec_mt = {
  __index = exec,
  __tostring = function(t)
    local es = t.exit_status or '?'
    return string.format('"%s" -> %s', t.cmd, es)
  end
}

function _M.exec(cmd, opt)
  local c = cmd_.new(cmd, opt)

  -- exec command
  c()

  return setmetatable({cmd = c}, exec_mt)
end

function exec.wait(self)
  self.exit_status = wait(self.cmd.pid)
  return self
end

-- pipeline --

local pipeline = {
  cmds          = {},
  exit_statuses = {},
}

local pipeline_mt = {
  __index = pipeline,
  __tostring = function(t)
    local len = #t.cmds
    local ret = table_new(len, 0)

    for i=1,len do
      local es = t.exit_statuses and t.exit_statuses[i] or '?'
      table.insert(ret, string.format('"%s" -> %s', t.cmds[i], es))
    end

    return table.concat(ret, '\n')
  end
}

function _M.pipeline()
  return setmetatable(pipeline, pipeline_mt)
end

function pipeline.add(self, cmd, opt)
  table.insert(self.cmds, cmd_.new(cmd, opt))

  return self
end

function pipeline.exec(self, opt)
  local pids = pipes(self.cmds)

  return self
end

function pipeline.wait(self)
  local cmds_len = #self.cmds

  for i=1,cmds_len do
    self.exit_statuses[i] = wait(self.cmds[i].pid)
  end

  return self
end

return _M

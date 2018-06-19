local S    = require 'syscall'
local libc = require 'lsh.libc'

local table_new = require 'table.new'
local table = table

--- execute program
-- @param cmd
-- @param[opt] args
-- @param[opt] options
local function spawn_proc(cmd, in_, out_, err_)
  local pid = S.fork()

  if pid == 0 then
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

    --TODO: handle gracefully
    local ret = libc.execvp(cmd[1], cmd)
    print("execvp ret is:", ret)
    os.exit(1)
    return
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

    local pid = spawn_proc(cmds[i], in_, w1)
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

local _M = {}

-- exec --

local exec = {}

local exec_mt = {
  __index = exec,
  __tostring = function(t)
    local es = t.exit_status or '?'
    local cmd = table.concat(t.cmd, ' ')
    return string.format('"%s" -> %s', cmd, es)
  end
}

function _M.exec(cmd, opt)
  assert(type(cmd) == "table")
  if opt then assert(type(opt) == "table") end

  local opt_ = opt or {}
  local cmd_ = opt_.noglob and cmd or glob_cmd(cmd)
  local exit_status

  local pid = spawn_proc(cmd_)

  return setmetatable({cmd         = cmd_,
                       exit_status = exit_status,
                       pid         = pid}, exec_mt)
end

function exec.wait(self)
  self.exit_status = wait(self.pid)
  return self
end

-- pipeline --

local pipeline = {
  cmds          = {},
  exit_statuses = {},
  opts          = {},
  pids          = {},
}

local pipeline_mt = {
  __index = pipeline,
  __tostring = function(t)
    local len = #t.cmds
    local res = {}
    local ret = table_new(len, 0)

    for i=1,len do
      local es = t.exit_statuses and t.exit_statuses[i] or '?'
      local cmd = table.concat(t.cmds[i], ' ')
      table.insert(ret, string.format('"%s" -> %s', cmd, es))
    end

    return table.concat(ret, '\n')
  end
}

function _M.pipeline()
  return setmetatable(pipeline, pipeline_mt)
end

function pipeline.add(self, cmd, opt)
  assert(type(cmd) == "table")
  if opt then assert(type(opt) == "table") end

  local next_i = #self.cmds + 1

  self.cmds[next_i] = cmd
  self.opts[next_i] = opt

  return self
end

function pipeline.exec(self, opt)
  local cmds_    = self.cmds
  local cmds_len = #cmds_

  for i=1,cmds_len do
    -- TODO: implement options
    local cmd = cmds_[i]
    self.cmds[i] = glob_cmd(cmd)
  end

  self.pids = pipes(cmds_)

  return self
end

function pipeline.wait(self)
  local pids_len = #self.pids

  for i=1,pids_len do
    self.exit_statuses[i] = wait(self.pids[i])
  end

  return self
end

return _M

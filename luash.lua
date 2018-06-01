local S    = require "syscall"
local libc = require 'luash.libc'

local table_new = require 'table.new'

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

local _M = {}
local mt = { __index = _M }

function _M.pipeline()
  return setmetatable({cmds = {}}, mt)
end

function _M.add(self, x, opt)
  table.insert(self.cmds, { x, opt })
  return self
end

function _M.exec(self, wait)
  local cmds_opts     = self.cmds
  local cmds_opts_len = #cmds_opts
  local cmds          = table_new(cmds_opts_len, 0)

  for i=1,cmds_opts_len do 
    -- TODO: implement options
    cmds[i] = cmds_opts[i][1]
  end

  local pids = pipes(cmds)

  local ret = table_new(cmds_opts_len, 0)
  for i=1,cmds_opts_len do
    local r, err, status = S.waitpid(pids[i], "ALL")
    -- TODO: normalize
    ret[i] = status
  end

  return ret
end

return _M

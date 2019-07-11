--- cmd structure
-- Create and manupulate commands and arguments.
-- @module lsh.cmd

local ffi = require 'ffi'
local S   = require 'syscall'

local libc   = require 'lsh.libc'
local tablex = require 'lsh.tablex'

ffi.cdef [[
int fileno(struct FILE* stream);
]]

local C = ffi.C

local function cmd_glob(cmd)
  local cmd_len = #cmd
  local cmd_globbed = tablex.new(cmd_len, 0)

  for i=1,cmd_len do
    local p = cmd[i]
    if type(p) == 'table' then -- glob only first level
      tablex.insert(cmd_globbed, p)
    else
      local res, err = libc.glob(p)

      if err then -- skip glob error
        tablex.insert(cmd_globbed, p)
      else
        for y=1,#res do tablex.insert(cmd_globbed, res[y]) end
      end
    end
  end

  return cmd_globbed
end

local function cmd_tbl_norm(c)
  local c_len = #c
  if c_len == 0 then
    return nil, 'empty table'
  end

  local cmd = tablex.new(c_len, 0)
  for i=1,c_len do
    local p = c[i]
    local p_type = type(p)

    if     p_type == 'string' then
      cmd[i] = p
    elseif p_type == 'number' then
      cmd[i] = tostring(p)
    elseif p_type == 'table' then
      local p_array, err = cmd_tbl_norm(p)
      if err then return nil, err end

      cmd[i] = p_array
    elseif p_type == 'cdata' then
      local p_str = tostring(p) -- try to convert to string (ffi.string ?)
      if not p_str then
        return nil, 'unable to convert '..p_type..' to string'
      end

      cmd[i] = p_str
    else
      return nil, 'invalid type '..p_type
    end
  end

  return cmd
end

local function cmd_norm(c)
  local c_type = type(c)

  if     c_type == 'table' then
    return cmd_tbl_norm(c)
  elseif c_type == 'function' then
    return c
  end

  return nil, 'invalid cmd type '..c_type

end

local function cmd_str(c)
  if type(c) == 'function' then
    return tostring(c)
  end

  local c_len = #c
  local ret = tablex.new(c_len, 0)

  for i=1,c_len do
    local p = c[i]
    local p_type = type(p)

    if p_type == 'table' then
      ret[i] = ("'%s'"):format(cmd_str(p))
    else
      ret[i] = p
    end
  end

  return tablex.concat(ret, ' ')
end

local opt_stdfds = {
  'stdout',
  'stdin',
  'stderr',
}

-- normalize options table
-- valid options:
--   env
--   workdir
--   stdout
--   stdin
--   stderr
--   noglob
local function opt_norm(o)
  local opt = {}

  local env = o.env
  if env then
    if type(env) ~= 'table' then
      return nil, 'env opt must be table'
    end
    opt.env = tablex.clone(env)
  end

  local workdir = o.workdir
  if workdir then
    if type(workdir) ~= 'string' then
      return nil, 'workidir opt must be string'
    end

    -- TODO: check if valid path
    opt.workdir = workdir
  end

  local noglob = o.noglob
  if noglob then
    if type(noglob) ~= 'boolean' then
      return nil, 'noglob opt must be boolean'
    end

    opt.noglob = noglob
  end

  for i=1,3 do
    local fd_name = opt_stdfds[i]
    local val = o[fd_name]

    if val then
      local val_type = type(val)

      if val_type == 'string' then -- path to file
        -- TODO: check if string is valid path
        opt[fd_name] = val
      elseif val_type == 'table' then -- fh/memfd
        local val_obj_type = val.type and val:type()
        if not val_obj_type == 'fh' or not val_obj_type == 'memfd' then
          return nil, ("%s opt is table, but not memfd or fh"):format(fd_name)
        end

        -- TODO: check fh/memfd permissions
        opt[fd_name] = val
      elseif val_type == 'userdata' then -- lua file handle
        -- allow only standard fds (0, 1, 2)
        local fd = tonumber(C.fileno(val))
        if fd == 0 then
          return nil, ("%s opt ambiguous redirect to fd %d"):format(fd_name, fd)
        elseif fd == 1 then
          opt[fd_name] = S.stdout
        elseif fd == 2 then
          opt[fd_name] = S.stderr
        else
          return nil, ("%s opt invalid fd %d"):format(fd_name, fd)
        end
      elseif val_type == 'cdata' then -- ljsyscall fd struct
        -- TODO: checks
        opt[fd_name] = val
      else
        return nil, ("%s opt invalid type %s"):format(fd_name, val_type)
      end
    end
  end

  return opt
end

-- cmd --
--
-- {
--   cmd         -- nested array of strings or function
--   opt         -- options dict
-- }
--
-- ex:
-- {
--   cmd = {'echo', 1, 'yes'}
-- }
--
-- {
--   cmd = {'parallel', '--no-notice',
--                      '-k',
--                      '-j6',
--                      {'zcat', '{}',
--                               '|',
--                               'jq', '-c',
--                                     {'.[]', '|', '.select(.id)'}
--                      }
--   },
--   opt = { workdir = '/tmp' }
-- }
--
-- TODO:
-- - cmd manipulation methods (push/pop/..)
--
local _M = {}
local cmd_mt = {
  __index = _M,
  __tostring = function(t)
    return cmd_str(t.cmd)
  end,
}

--- create new @{cmd} instance and normalize input
-- @param c table or function
-- @param o table
-- @return new @{cmd} instance
function _M.new(c, o)
  local c_type = type(c)
  assert(c_type == 'table' or c_type == 'function',
         'first arg must be table or function')
  local cn, err = cmd_norm(c)
  if err then return nil, err end

  local on = {}
  if o then
    assert(type(o) == 'table', 'second arg must be table')
    local err
    on, err = opt_norm(o)
    if err then return nil, err end
  end

  return setmetatable({cmd = cn, opt = on}, cmd_mt)
end


--- clone cmd instance
-- @param self @{cmd}
-- @return new @{cmd} instance, clone of `self`
function _M.clone(self)
  assert(self)

  return setmetatable({
    cmd = tablex.clone(self.cmd, true), -- it will return input if not table
    opt = self.opt and tablex.clone(self.opt, true) or {},
  }, cmd_mt)
end

--- get the type of a command (table or function)
-- @param self @{cmd}
-- @return `("cmd", command_type)` where command_type is `table` or `function` if the input is a cmd, else `false`
function _M.type(self)
  if type(self) ~= 'table' then return false end
  local is_cmd = getmetatable(self) == cmd_mt
  if is_cmd then
    return 'cmd', type(self.cmd)
  end

  return false
end


--- set command options
-- @param self @{cmd}
-- @param o table
-- @return self
function _M.set_opt(self, o)
  if type(o) ~= 'table' then return nil end
  local opt, err = opt_norm(o)
  if err then return nil, err end

  -- TODO: table of valid options
  for k, v in pairs(opt) do
    self.opt[k] = v
  end

  return self
end


--- evaluate globs in a table cmd.
-- @param self @{cmd}
-- @return self
function _M.glob(self)
  local cmd = self.cmd
  if type(cmd) == 'function' then
    return nil, 'unable to glob function'
  end

  return cmd_glob(cmd)
end

local mt = {
  __index = _M,
  __call = function(_, c, o)
    return _M.new(c, o)
  end,
}

return setmetatable({}, mt)

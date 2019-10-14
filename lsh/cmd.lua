-- cmd structure
--
-- Create and manupulate command and its options
--

local ffi = require 'ffi'
local S   = require 'syscall'

local tablex = require 'lsh.tablex'
local path   = require 'lsh.path'

local exec   = require 'lsh.cmd.exec'

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"

ffi.cdef [[
int fileno(struct FILE* stream);
]]

local C = ffi.C

local function cpart_norm(cpart)
  local cpart_type = type(cpart)

  if     cpart_type == 'string' then
    return cpart
  elseif cpart_type == 'number' then
    return tostring(cpart)
  elseif cpart_type == 'table' then
    local res, err
    -- TODO: native path support
    if cpart.type and cpart:type() == 'path' then
      return tostring(cpart)
    end

    return table.concat(cpart, ' ')
  elseif cpart_type == 'cdata' then
    local res = tostring(cpart) -- try to convert to string (ffi.string ?)
    if not res then
      return nil, 'unable to convert '..cpart_type..' to string'
    end

    return res
  end

  return nil, 'invalid type '..cpart_type
end

local stdfd_obj_types = {
  memfd = true,
  fh =    true,
  path =  true,
}

local function norm_stdfd(x)
  local x_type = type(x)

  if x_type == 'string' then -- path to file
    local p, err = path.new(x)
    if err then return nil, err end
    return p
  elseif x_type == 'table' then -- path/fh/memfd
    local obj_type = x.type and x:type()
    if not stdfd_obj_types[obj_type] then
      return nil, "table must be path/memfd/fh type"
    end
    -- TODO: check fh/memfd permissions
    return x
  elseif x_type == 'userdata' then -- lua file handle?
    -- allow only standard fds (0, 1, 2)
    local fd = tonumber(C.fileno(x))
    if fd == 0 then
      return nil, ("ambiguous redirect to fd %d"):format(fd)
    elseif fd == 1 then
      return S.stdout
    elseif fd == 2 then
      return S.stderr
    end
    return nil, ("invalid userdata fd %d"):format(fd)
  elseif x_type == 'cdata' then -- ljsyscall fd struct
    -- TODO: checks
    return x
  end

  return nil, ("invalid type %s"):format(x_type)
end

-- cmd --
--
-- {
--   -- array of command and args
--   -- map part of table for options
-- }
--
local methods = tablex.new(0, 10)

function methods.clone(self)
  assert(self)

  return tablex.clone(self, true)
end

function methods.run(self)
  return exec(self):wait()
end

function methods.exec(self)
  return exec(self)
end

-- return cmd type
function methods.type()
  return 'cmd'
end

local function cmd_appned(cmd, x)
  local cpart, err = cpart_norm(x)
  if not cpart then return nil, err end
  table.insert(cmd, cpart)

  return true
end

function methods.append(self, ...)
  for i=1,select('#', ...) do
    local ok, err = cmd_appned(self, select(i, ...))
    if not ok then
      return nil, ("invalid arg %d: %s"):format(i, err)
    end
  end

  return self
end

function methods.extend(self, ...)
  for i=1,select('#', ...) do
    local tbl = select(i, ...)
    if type(tbl) ~= 'table' then
      return nil, ("arg %d must be table"):format(i)
    end
    for j=1,#tbl do
      local ok, err = cmd_appned(self, tbl[j])
      if not ok then
        return nil, ("invalid arg %d, index %d: %s"):format(i, j, err)
      end
    end
  end

  return self
end

function methods.insert(self, i, x)
  if type(i) ~= 'number' then
    error(err_str:format(2, 'insert', 'number', type(i)), 2)
  end
  local cpart, err = cpart_norm(x)
  if not cpart then return nil, err end
  table.insert(self, i, cpart)

  return self
end

function methods.remove(self, i)
  if type(i) ~= 'number' then
    error(err_str:format(2, 'remove', 'number', type(i)), 2)
  end
  table.remove(self, i)

  return self
end

-- cmd options --

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

function methods.env(self, env)
  if not env then
    self._env = nil
    return self
  end

  if type(env) ~= 'table' then
    error(err_str:format(2, 'env', 'table or nil', type(env)), 2)
  end
  self._env = tablex.clone(env)

  return self
end

function methods.glob(self, glob)
  if type(glob) ~= 'boolean' then
    error(err_str:format(2, 'glob', 'boolean', type(glob)), 2)
  end
  self._glob = glob

  return self
end


function methods.stdin(self, val)
  if not val then
    self._stdin = nil
    return self
  end

  local res, err = norm_stdfd(val)
  if err then return nil, err end
  self._stdin = res

  return self
end

function methods.stdout(self, val)
  if not val then
    self._stdout = nil
    return self
  end

  local res, err = norm_stdfd(val)
  if err then return nil, err end
  self._stdout = res

  return self
end

function methods.stderr(self, val)
  if not val then
    self._stderr = nil
    return self
  end

  local res, err = norm_stdfd(val)
  if err then return nil, err end
  self._stderr = res

  return self
end

local _M = tablex.new(0, 2)
local cmd_mt = {
  __index = methods,
  __tostring = function(t)
    return table.concat(t, ' ')
  end,
}

-- create new cmd instance and normalize input
function _M.new(...)
  local len = select('#', ...)
  if len <= 0 then return nil, 'no args' end

  local cmd = tablex.new(len, 1)
  for i=1,len do
    local cpart = select(i, ...)
    if cpart then
      local res, err = cpart_norm(cpart)
      -- todo: better error handling
      if not res then return nil, err end
      table.insert(cmd, res)
    end
  end

  -- glob by default
  cmd._glob = true

  return setmetatable(cmd, cmd_mt)
end

-- return 'cmd' if input is cmd type
function _M.type(tbl)
  if type(tbl) ~= 'table' then return nil end
  local is_cmd = getmetatable(tbl) == cmd_mt
  if is_cmd then
    return 'cmd'
  end

  return nil
end

local mt = {
  __call = function(_, ...)
    return _M.new(...)
  end,
}

return setmetatable(_M, mt)

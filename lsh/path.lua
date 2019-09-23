-- path - path object

local ffi = require 'ffi'
local S = require 'syscall'

local fio    = require 'lsh.fio'
local tablex = require 'lsh.tablex'

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"

ffi.cdef [[
char *dirname(char *path);
]]

local C = ffi.C
local buf_t = ffi.typeof('char[?]')
local pagesize = S.getpagesize()

-- TODO: extend normalization
local function norm_path(str)
  local path = str:gsub('/+', '/')
  if path ~= '/' then
    path = path:gsub('/$', '')
  end

  return path
end

local function norm_path_part(part)
  local part_type = type(part)

  if part_type     == 'string' then
    return part
  elseif part_type == 'number' then
    return tostring(part)
  elseif part_type == 'table' then
    if part.type and part:type() == 'path' then
      return tostring(part)
    end
    return nil, 'invalid type table'
  end

  return nil, ("invalid type %s"):format(part_type)
end

-- based on tarantool (2.1) src/lua/fio.lua
-- TODO: total rework, check when concating absolute paths
-- https://github.com/moteus/lua-path/blob/master/lua/path.lua#L134
local function join(...)
  local i, path = 1, nil

  local len = select('#', ...)
  while i <= len do
    local sp = select(i, ...)

    if sp then
      local spn, err = norm_path_part(sp)
      if err then return nil, err end
      if spn ~= '' then
        path = spn
        break
      end
    end

    i = i + 1
  end

  if path == nil then
    return '.'
  end

  i = i + 1
  while i <= len do
    local sp = select(i, ...)

    if sp then
      local spn, err = norm_path_part(sp)
      if err then return nil, err end
      if spn ~= '' then
        path = path .. '/' .. spn
      end
    end

    i = i + 1
  end

  return norm_path(path)
end

local methods = tablex.new(0, 25)
local attrs = tablex.new(0, 8)

local path_mt = {
  __index = function (t, k)
    if attrs[k] then
      return attrs[k](t)
    end

    return methods[k]
  end,
  __newindex = function()
    error('attempt to index a path object')
  end,
  __tostring = function(t)
    return t.path
  end
}

-- attrs --

function attrs.name(p)
  return string.gsub(p.path, '.*/', '')
end

function attrs.parent(p)
  local buf = buf_t(#p.path + 1, p.path)

  return methods.new(ffi.string(C.dirname(buf)))
end

function attrs.parents(p)
  error('not implemented')
end

-- split a path into root and extension part
local function splitext(path)
  local i = #path
  local ch = path:sub(i, i)
  while i > 0 and ch ~= '.' do
    if ch == '/' then
      return path, ''
    end
    i = i - 1
    ch = path:sub(i, i)
  end

  if i == 0 then
    return path, ''
  end

  return path:sub(1, i-1), path:sub(i)
end

function attrs.suffix(p)
  local _, ext = splitext(p.path)
  return ext
end

function attrs.suffixes(p)
  local path, ext = p.path
  local ret = {}

  while true do
    path, ext = splitext(path)
    if ext == '' then
      return ret
    end
    table.insert(ret, ext)
  end
end

function attrs.stem(p)
  error('not implemented')
end

function attrs.parts(p)
  local parts = {}

  if string.sub(p.path, 1, 1) == '/' then
    table.insert(parts, '/')
  end

  for sp in string.gmatch(p.path, '[^/]+') do
    table.insert(parts, sp)
  end

  return parts
end

function attrs.root(p)
  error('not implemented')
end

-- methods --

function methods.new(...)
  local path, err = join(...)
  if err then return nil, err end

  return setmetatable({path = path}, path_mt)
end

function methods.type(self)
  if type(self) ~= 'table' then return nil end
  if getmetatable(self) == path_mt then
    return 'path'
  end

  return nil
end

function methods.chdir(self)
  local ok, err = S.chdir(self.path)
  return ok, tostring(err)
end

function methods.open(self, flags, mode)
  return fio.open(self.path, flags, mode)
end

function methods.joinpath(self, ...)
  return methods.new(self.path, ...)
end

-- TODO: support symlink resolution
function methods.resolve(self)
  local joined_path = ''
  local path_tab = {}

  if string.sub(self.path, 1, 1) == '/' then
    joined_path = self.path
  else
    joined_path = join(S.getcwd(), self.path)
  end

  for sp in string.gmatch(joined_path, '[^/]+') do
    if sp == '..' then
      table.remove(path_tab)
    elseif sp ~= '.' then
      table.insert(path_tab, sp)
    end
  end

  return methods.new('/' .. table.concat(path_tab, '/'))
end

function methods.exists(self)
  if self:stat() then
    return true
  end

  return false
end

-- TODO: wrap syscall stat object
function methods.stat(self)
  return S.stat(self.path)
end

function methods.isreg(self)
  local st = self:stat()
  if st then
    return st.isreg
  end

  return false
end

methods.isfile = methods.isreg

function methods.isdir(self)
  local st = self:stat()
  if st then
    return st.isdir
  end

  return false
end

function methods.islnk(self)
  local st = self:stat()
  if st then
    return st.islnk
  end

  return false
end

function methods.issock(self)
  local st = self:stat()
  if st then
    return st.issock
  end

  return false
end

function methods.isfifo(self)
  local st = self:stat()
  if st then
    return st.isfifo
  end

  return false
end

function methods.isblk(self)
  local st = self:stat()
  if st then
    return st.isblk
  end

  return false
end

function methods.ischar(self)
  local st = self:stat()
  if st then
    return st.ischar
  end

  return false
end

function methods.setxattr(self, name, value, flag)
  if type(name) ~= 'string' then
    error(err_str:format(2, 'setxattr', 'string', type(name)), 2)
  end
  if type(value) ~= 'string' then
    error(err_str:format(3, 'setxattr', 'string', type(value)), 2)
  end

  local ok, err = S.setxattr(self.path, name, value, flag)
  if not ok then
    return nil, tostring(err)
  end

  return true
end

function methods.getxattr(self, name)
  if type(name) ~= 'string' then
    error(err_str:format(2, 'getxattr', 'string', type(name)), 2)
  end

  local res, err = S.getxattr(self.path, name)
  if err then
    return nil, tostring(err)
  end

  return res
end

function methods.removexattr(self, name)
  if type(name) ~= 'string' then
    error(err_str:format(2, 'removexattr', 'string', type(name)), 2)
  end

  local ok, err = S.removexattr(self.path, name)
  if err then
    return nil, tostring(err)
  end

  return ok
end

function methods.listxattr(self)
  local res, err = S.listxattr(self.path)
  if err then
    return nil, tostring(err)
  end

  return res
end

function methods.mkdir(self, mode, parents, exists)
  if parents then
    local i, pparts = 1, self.parent.parts
    local pparts_len = #pparts
    local path = ""

    -- find missing dir in path
    while i <= pparts_len do
      local p = methods.new(path, pparts[i])

      if not p:exists() then
        break
      end

      if not p:isdir() then
        return nil, ("path %s: not a directory"):format(p)
      end

      path = tostring(p)
      i = i + 1
    end

    -- create rest of the dirpath
    while i <= pparts_len do
      path = join(path, pparts[i])
      local _, err = S.mkdir(path, '0755')
      if err then
        return nil, tostring(err)
      end

      i = i + 1
    end
  end

  if mode and type(mode) ~= 'string' then
    error(err_str:format(2, 'mkdir', 'string or nil', type(mode)), 2)
  else
    mode = '0755'
  end

  local ok, err = S.mkdir(self.path, mode)
  if err then
    if err.EXIST and exists then
      return true
    end

    return nil, tostring(err)
  end

  return ok
end

function methods.rmdir(self)
  return S.rmdir(self.path)
end

local function dir_close(dir)
  dir.fd:close()
  dir.fd = nil
end

local function dir_next(dir)
  if not dir.fd then
    return nil, "dir ended"
  end
  local d
  repeat
    if not dir.di then
      local err
      dir.di, err = dir.fd:getdents(dir.buf, dir.size)
      if not dir.di then
        dir_close(dir)
        return nil, tostring(err)
      end
    end

    d = dir.di()
    if not d then
      dir_close(dir)
      return nil
    end

    if d.name == '.' or d.name == '..' then
      d = nil
    end
  until d

  return methods.new(d.name)
end

function methods.lsdir(self)
  local size = pagesize
  local buf = S.t.buffer(size)
  local fd, err = S.open(self.path, 'directory, rdonly')
  if err then return nil, tostring(err) end

  return dir_next, {size = size,
                    buf = buf,
                    fd = fd,
                    next = dir_next,
                    close = dir_close}
end

function methods.touch(self, mode, exists)
  if self:exists() and exists then
    S.utime(self.path)
    return true
  else
    return nil, 'file exists'
  end
  if mode and type(mode) ~= 'string' then
    error(err_str:format(2, 'touch', 'string or nil', type(mode)), 2)
  else
    mode = '0666'
  end

  local ok, err = S.creat(self.path, mode)
  if err then
    return nil, tostring(err)
  end

  return ok
end

function methods.unlink(self)
  local ok, err = S.unlink(self.path)
  if err then
    return nil, tostring(err)
  end

  return ok
end

local _M = tablex.new(0, 3)

function _M.new(...)
  return methods.new(...)
end

function _M.cwd()
  local cwd, err = S.getcwd()
  if err then
    return nil, tostring(err)
  end

  return methods.new(cwd)
end

function _M.home()
  return methods.new(os.getenv('HOME'))
end

local mt = {
  __index = _M,
  __call = function(_, ...)
    return methods.new(...)
  end
}

return setmetatable({}, mt)

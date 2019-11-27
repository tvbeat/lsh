--- create and manipulate filesystem paths
-- @module lsh.path

local ffi = require 'ffi'
local S = require 'syscall'

local tablex = require 'lsh.tablex'
local fio    = require 'lsh.fio'
local libc   = require 'lsh.libc'

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
  end,
  __eq = function (l, r)
    return l.path == r.path
  end,
}

-- attrs --

--- get path name as string
-- @tparam lsh.path self
-- @treturn string path name as string
function attrs.name(self)
  return string.gsub(self.path, '.*/', '')
end

--- get parent directory
-- @tparam lsh.path self
-- @treturn lsh.path parent directory
function attrs.parent(self)
  local buf = buf_t(#self.path + 1, self.path)

  return methods.new(ffi.string(C.dirname(buf)))
end

function attrs.parents(self)
  error('not implemented')
end

--- split a path into basename and extension part
-- @tparam string path
-- @treturn[1] string basename
-- @treturn[1] string extension
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

--- return the path's extension
-- @tparam lsh.path self
-- @treturn string the extension
function attrs.suffix(self)
  local _, ext = splitext(self.path)
  return ext
end

--- return the path's extensions
-- @tparam lsh.path self
-- @treturn array-of-string extensions
function attrs.suffixes(self)
  local path, ext = self.path
  local ret = {}

  while true do
    path, ext = splitext(path)
    if ext == '' then
      return ret
    end
    table.insert(ret, ext)
  end
end

function attrs.stem(path)
  error('not implemented')
end

--- return the path's parts
-- @tparam lsh.path self
-- @treturn array-of-string parts
function attrs.parts(self)
  local parts = {}

  if string.sub(self.path, 1, 1) == '/' then
    table.insert(parts, '/')
  end

  for sp in string.gmatch(self.path, '[^/]+') do
    table.insert(parts, sp)
  end

  return parts
end

function attrs.root(p)
  error('not implemented')
end

-- methods --

--- create new @{path} instance
-- @param  ... TODO
-- @treturn[0] path
-- @treturn[1] nil
-- @treturn[1] string error
function methods.new(...)
  local path, err = join(...)
  if err then return nil, err end

  return setmetatable({path = path}, path_mt)
end

--- get type
-- @tparam lsh.path self
-- @treturn[0] string `"path"` if argument is a @{path}
-- @treturn[1] nil otherwise
function methods.type(self)
  if type(self) ~= 'table' then return nil end
  if getmetatable(self) == path_mt then
    return 'path'
  end

  return nil
end

--- change directory
-- @tparam lsh.path self
-- @treturn[0] bool `true`
-- @treturn[1] nil
-- @treturn[1] string error
function methods.chdir(self)
  local ok, err = S.chdir(self.path)
  return ok, tostring(err)
end

--- open
-- @tparam lsh.path self
-- @param flags TODO
-- @param mode TODO
-- @return TODO
function methods.open(self, flags, mode)
  return fio.open(self.path, flags, mode)
end

--- join paths
-- @tparam lsh.path self
-- @tparam string ... path parts to append to self
-- @treturn lsh.path new path with the arguments appended to self
function methods.joinpath(self, ...)
  return methods.new(self.path, ...)
end

--- resolve relative path
-- @tparam lsh.path self
-- @treturn lsh.path `self` resolved to absolute path
function methods.resolve(self)
  -- TODO: support symlink resolution
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

--- check if file path exists
-- @tparam lsh.path self
-- @treturn bool `true` if the path exists
function methods.exists(self)
  if self:stat() then
    return true
  end

  return false
end

--[[- Glob the given relative pattern in the directory represented
by this path, yielding all matching files (of any kind).

@function glob
@todo recursive globbing
@tparam lsh.path self
@tparam string pattern pattern to match
@treturn[1] {lsh.path,...} array of `path` instances
@treturn[1] table map of path keys and err string values (if any)
@treturn[2] nil
@treturn[2] string error message
@usage
local sh = require 'lsh'

sh.path('.'):glob('*.lua')

local res, err = sh.path('/'):glob('*/*')
assert(type(res) = 'table')
if err then
  for k,v in pairs(err) do print(k,v) end
end
--> /root	Permission denied
]]
function methods.glob(self, pattern)
  if type(pattern) ~= 'string' then
    error(err_str:format(2, 'glob', 'string', type(pattern)), 2)
  end
  if not self:isdir() then
    return nil, 'path must be directory'
  end

  local ppattern = ("%s/%s"):format(self, pattern)
  local paths, err = libc.glob(ppattern)
  if not paths then
    return nil, err
  end

  local len = #paths
  local res = tablex.new(len, 0)
  for i=1,len do
    res[i] = methods.new(paths[i])
  end

  return res, err
end

--- get metadata
-- @tparam lsh.path self
-- @return TODO
function methods.stat(self)
  -- TODO: wrap syscall stat object
  return S.stat(self.path)
end

--- check if path is a regular file
-- @tparam lsh.path self
-- @treturn bool `true` if path is a regular file
function methods.isreg(self)
  local st = self:stat()
  if st then
    return st.isreg
  end

  return false
end

methods.isfile = methods.isreg

--- check if path is a directory
-- @tparam lsh.path self
-- @treturn bool `true` if path is a directory
function methods.isdir(self)
  local st = self:stat()
  if st then
    return st.isdir
  end

  return false
end

--- check if path is a link
-- @tparam lsh.path self
-- @treturn bool `true` if path is a link
function methods.islnk(self)
  local st = self:stat()
  if st then
    return st.islnk
  end

  return false
end

--- check if path is a socket
-- @tparam lsh.path self
-- @treturn bool `true` if path is a socket
function methods.issock(self)
  local st = self:stat()
  if st then
    return st.issock
  end

  return false
end

--- check if path is a pipe
-- @tparam lsh.path self
-- @treturn bool `true` if path is a pipe
function methods.isfifo(self)
  local st = self:stat()
  if st then
    return st.isfifo
  end

  return false
end

--- check if path is a block device
-- @tparam lsh.path self
-- @treturn bool `true` if path is a block device
function methods.isblk(self)
  local st = self:stat()
  if st then
    return st.isblk
  end

  return false
end

--- check if path is a character device
-- @tparam lsh.path self
-- @treturn bool `true` if path is a character device
function methods.ischar(self)
  local st = self:stat()
  if st then
    return st.ischar
  end

  return false
end

--- set extended attribute
-- @tparam lsh.path self
-- @tparam string name
-- @tparam string value
-- @tparam ?string flag `"CREATE"` or `"REPLACE"`
-- @treturn[0] bool `true`
-- @treturn[1] nil
-- @treturn[1] string error
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

--- get extended attribute
-- @tparam lsh.path self
-- @tparam string name
-- @treturn[0] bool `true`
-- @treturn[1] nil
-- @treturn[1] string error
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

--- remove extended attribute
-- @tparam lsh.path self
-- @tparam string name
-- @treturn[0] bool `true`
-- @treturn[1] nil
-- @treturn[1] string error
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

--- list extended attributes
-- @tparam lsh.path self
-- @treturn[0] table table of extended attribute names to values
-- @treturn[1] nil
-- @treturn[1] string error
function methods.listxattr(self)
  local res, err = S.listxattr(self.path)
  if err then
    return nil, tostring(err)
  end

  return res
end

--- create directory
-- @tparam lsh.path self
-- @param mode TODO
-- @tparam bool parents wether to create parent directories
-- @param exists TODO unused?
-- @return TODO
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

--- remove directory
-- @tparam lsh.path self
-- @return TODO
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

--- list directory
-- @tparam lsh.path self
-- @treturn[0] iterator @{lsh.path}s in the directory
-- @treturn[1] nil
-- @treturn[1] string error
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

--- update modified date or create a file
-- @tparam lsh.path self
-- @param mode TODO
-- @param exists TODO
-- @return TODO
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

--- delete file
-- @tparam lsh.path self
-- @treturn[0] bool `true`
-- @treturn[1] nil
-- @treturn[1] string error
function methods.unlink(self)
  local ok, err = S.unlink(self.path)
  if err then
    return nil, tostring(err)
  end

  return ok
end

local _M = tablex.new(0, 3)

--- create new @{path} instance
-- @param ... TODO
-- @treturn[0] lsh.path new @{path} instance
-- @treturn[1] nil
-- @treturn[1] string error
function _M.new(...)
  return methods.new(...)
end

--- get working directory
-- @treturn[0] lsh.path current working directory
-- @treturn[1] nil
-- @treturn[1] string error
function _M.cwd()
  local cwd, err = S.getcwd()
  if err then
    return nil, tostring(err)
  end

  return methods.new(cwd)
end

--- get home directory
-- @treturn[0] lsh.path home directory
-- @treturn[1] nil
-- @treturn[1] string error
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

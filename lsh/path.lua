--[[- Create and manipulate filesystem paths.
@module lsh.path
]]

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

local _M = tablex.new(0, 3)

--- Path attributes.
-- @section pathattr
local attrs = tablex.new(0, 7)

--[[- A string representing the final path component.
@function name
@treturn string final path of component
@usage
local sh = require 'lsh'

local name = sh.path('dev/init.lua').name
assert(name == 'init.lua')
]]
function attrs.name(self)
  return string.gsub(self.path, '.*/', '')
end

--[[- The logical parent of the path.
@function parent
@treturn lsh.path parent
@usage
local sh = require 'lsh'

local p = sh.path('a/b/c/d/e')
assert(p.parent == p.path('a/b/c/d'))

p = sh.path('/')
assert(p.parent == p.path('/'))
p = sh.path('.')
assert(p.parent == p.path('.'))
]]
function attrs.parent(self)
  local buf = buf_t(#self.path + 1, self.path)

  return _M.new(ffi.string(C.dirname(buf)))
end

--[[- An array providing access to the logical ancestors of the path.
@function parents
@treturn {lsh.path,...} array of logical ancestors
@usage
local sh = require 'lsh'

local p = sh.path('/usr/local/bin/lua')
assert(p.parents[1] == p.path('/usr/local/bin'))
assert(p.parents[2] == p.path('/usr/local'))
assert(p.parents[3] == p.path('/usr'))
assert(p.parents[4] == p.path('/'))
]]
function attrs.parents(self)
  local parts = self.parent.parts
  local parts_len = #parts

  local res = tablex.new(parts_len, 0)
  local par
  for i=1,parts_len do
    par = par and par:join(parts[i]) or _M.new(parts[i])
    table.insert(res, 1, par)
  end

  return res
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

--[[- The file extension of the final component (if any).
@function suffix
@treturn string suffix
@usage
local sh = require 'lsh'

assert(sh.path('dev/init.lua').suffix == 'lua')
assert(sh.path('my/lib.tar.gz').suffix == 'gz')
assert(sh.path('my/lib').suffix == '')
]]
function attrs.suffix(self)
  local _, ext = splitext(self.path)
  return ext
end

--[[- A array of the path's file extensions.
@function suffixes
@treturn {string,...} array of extensions
@usage
local sh = require 'lsh'

local sx = p.path('my/lib.tar.gar').suffixes
assert(sx[1] == 'tar')
assert(sx[2] == 'gar')

sx = p.path('my/lib').suffixes
assert(#sx == 0)
]]
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

--[[- The final path component, without its suffix.
@function stem
@treturn string
@usage
local sh = require 'lsh'

assert(p.path('my/lib.tar.gz').stem == 'lib.tar')
assert(p.path('my/lib.tar').stem == 'lib')
assert(p.path('my/lib').stem == 'lib')
]]
function attrs.stem(self)
  local name = self.name
  local i = #name
  local ch = name:sub(i, i)
  while i > 0 and ch ~= '.' do
    i = i - 1
    ch = name:sub(i, i)
  end

  if i == 0 then
    return name
  end

  return name:sub(1, i-1)
end

--[[- A array giving access to the path's various components.
@function parts
@treturn {string,...}
@usage
local sh = require 'lsh'

local p = sh.path('/usr/local/bin/lua')
assert(p.parts[1] == '/')
assert(p.parts[2] == 'usr')
assert(p.parts[3] == 'local')
assert(p.parts[4] == 'bin')
assert(p.parts[5] == 'lua')
]]
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

--- Path methods.
-- @section pathmethods
local methods = tablex.new(0, 25)

--[[- Returns the type of the instance.
@function type
@return the string `"path"`
@usage
local sh = require 'lsh'

assert(sh.path('/'):type() == 'path')
]]
function methods.type()
  return 'path'
end

--[[- Calling this method is equivalent to combining the path
with each of the other arguments in turn.
@function join
@tparam lsh.path self
@tparam ... ... `string`, `number` or @{lsh.path}
@treturn[1] lsh.path new joined `path` instance
@treturn[2] nil
@treturn[2] string error message
@usage
local sh = require 'lsh'

local p = sh.path('/etc')
assert(p:join('passwd') == sh.path('/etc/passwd'))
assert(p:join(sh.path('passwd')) == sh.path('/etc/passwd'))
assert(p:join('nginx', 'nginx.conf') == sh.path('/etc/nginx/nginx.conf'))
]]
function methods.join(self, ...)
  return _M.new(self.path, ...)
end

--[[- Compute a version of this path relative to the path
represented by other. If it's impossible, nil and err are returned.
@function relative_to
@tparam lsh.path self
@tparam lsh.path|string other
@treturn[1] lsh.path new relative `path` instance
@treturn[2] nil
@treturn[2] string error message
@usage
local sh = require 'lsh'

local p = sh.path('/etc/passwd')
assert(p:relative_to('/') == sh.path('etc/passwd'))
assert(p:relative_to('/etc') == sh.path('passwd'))
]]
function methods.relative_to(self, other)
  local err_fmt = "%s does not start with %s"
  other = _M.new(other)

  local selfp, otherp = self.parts, other.parts
  local selfp_len, otherp_len = #selfp, #otherp
  if selfp_len < otherp_len then
    return nil, (err_fmt):format(self, other)
  end

  local n = math.min(selfp_len, otherp_len)
  for i=1,n do
    if selfp[i] ~= otherp[i] then
      return nil, (err_fmt):format(self, other)
    end
  end

  local rel = {}
  for i=n+1,#selfp do
    table.insert(rel, selfp[i])
  end

  return _M.new(unpack(rel))
end

--[[- Change working directory.
@function chdir
@tparam lsh.path self
@treturn[1] lsh.path self
@treturn[2] nil
@treturn[2] string error message
@usage
local sh = require 'lsh'

sh.path('/home/user'):chdir()
]]
function methods.chdir(self)
  local ok, err = S.chdir(self.path)
  if not ok then
    return ok, tostring(err)
  end

  return self
end

--[[- Calls @{lsh.fio.open} on path instance and returning
a @{lsh.fio.fh} file handle.

**This interface is not finalized and it will be changed
in incompatible ways!**

@function open
@tparam lsh.path self
@tparam table flags `lsh.fio.open` flags
@tparam table mode `lsh.fio.open` mode
@treturn[1] lsh.fio.fh file handle
@treturn[2] nil
@treturn[2] string error message
@usage
local sh = require 'lsh'

local fh = sh.path('/home/user'):open()
]]
function methods.open(self, flags, mode)
  return fio.open(self.path, flags, mode)
end

--[[- Rename this file or directory to the given `target`,
and return a new path instance pointing to `target`.

If `target` exists and is a file, it will be replaced silently
if the user has permission. `target` can be either a string
or another path object.

@function rename
@tparam lsh.path self
@tparam string|lsh.path target
@treturn[1] lsh.path
@treturn[2] nil
@treturn[2] string error message
@usage
local sh = require 'lsh'

local p = sh.path('foo')
assert(p:rename('bar') == sh.path('bar'))
]]
function methods.rename(self, target)
  local s = tostring(self)
  local t
  if type(target) == 'string' then
    t = target
    target = _M.new(target)
  elseif type(target) == 'table' then
    t = tostring(target)
  else
    error(err_str:format(2, 'rename', 'string or lsh.path', type(target)), 2)
  end

  local ok, err = os.rename(s, t)
  if not ok then
    return nil, err
  end

  return target
end

--[[- Make the path absolute, resolving any symlinks.

**Symlink resolving is not finished yet.**

@function resolve
@tparam lsh.path self
@treturn[1] lsh.path resolved `path` instance
@treturn[2] nil
@treturn[2] string error message
@usage
local sh = require 'lsh'

local p = sh.path('.')
assert(p:resolve() == sh.path.cwd())
]]
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

  return _M.new('/' .. table.concat(path_tab, '/'))
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
  if not self:is_dir() then
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
    res[i] = _M.new(paths[i])
  end

  return res, err
end

--[[- Return file metadata.

**This interface is not finalized and it will be changed
in incompatible ways!**

@function stat
@tparam lsh.path self
@treturn[1] cdata ljsyscall stat_t
@treturn[2] nil
@usage
local sh = require 'lsh'

local st = sh.path('.'):stat()
]]
function methods.stat(self)
  -- TODO: wrap syscall stat object
  return S.stat(self.path)
end

--[[- Returns path with appended trailing slash.
@function with_slash
@tparam lsh.path self
@treturn string path with trailing slash
@usage
local sh = require 'lsh'

assert(sh.path('/var'):with_slash() == '/var/')
assert(sh.path('log.txt'):with_slash() == 'log.txt/')
assert(sh.path('/'):with_slash() == '/')
]]
function methods.with_slash(self)
  local path = self.path
  if path == '/' then
    return path
  end

  return ("%s/"):format(path)
end

--[[- Whether the path points to an existing file or directory.
@function exists
@tparam lsh.path self
@treturn[1] lsh.path `self`
@treturn[2] false
@usage
local sh = require 'lsh'

assert(sh.path('.'):exists())
]]
function methods.exists(self)
  if self:stat() then
    return self
  end

  return false
end

--[[- Return `self` if the path points to a regular file,
`false` otherwise.

`false` is also returned if the path doesn’t exist
or is a broken symlink.

@function is_file
@tparam lsh.path self
@treturn[1] lsh.path `self`
@treturn[2] false
@usage
local sh = require 'lsh'

assert(sh.path('/etc/resolv.conf'):is_file())
]]
function methods.is_file(self)
  local st = self:stat()
  if st and st.isreg then
    return self
  end

  return false
end

--[[- Return `self` if the path points to a directory,
`false` otherwise.

`false` is also returned if the path doesn’t exist
or is a broken symlink.

@function is_dir
@tparam lsh.path self
@treturn[1] lsh.path `self`
@treturn[2] false
]]
function methods.is_dir(self)
  local st = self:stat()
  if st and st.isdir then
    return self
  end

  return false
end

--[[- Return `self` if the path points to symbolic link,
`false` otherwise.

`false` is also returned if the path doesn’t exist.

@function is_link
@tparam lsh.path self
@treturn[1] lsh.path `self`
@treturn[2] false
]]
function methods.is_link(self)
  local st = self:stat()
  if st and st.islnk then
    return self
  end

  return false
end

--[[- Return `self` if the path points to socket,
`false` otherwise.

`false` is also returned if the path doesn’t exist or
is a broken symlink.

@function is_sock
@tparam lsh.path self
@treturn[1] lsh.path `self`
@treturn[2] false
]]
function methods.is_sock(self)
  local st = self:stat()
  if st and st.issock then
    return self
  end

  return false
end

--[[- Return `self` if the path points to a FIFO,
`false` otherwise.

`false` is also returned if the path doesn’t exist or
is a broken symlink.

@function is_fifo
@tparam lsh.path self
@treturn[1] lsh.path `self`
@treturn[2] false
]]
function methods.is_fifo(self)
  local st = self:stat()
  if st and st.isfifo then
    return self
  end

  return false
end

--[[- Return `self` if the path points to a block device,
`false` otherwise.

`false` is also returned if the path doesn’t exist or
is a broken symlink.

@function is_blk
@tparam lsh.path self
@treturn[1] lsh.path `self`
@treturn[2] false
]]
function methods.is_blk(self)
  local st = self:stat()
  if st and st.isblk then
    return self
  end

  return false
end

--[[- Return `self` if the path points to a character device,
`false` otherwise.

`false` is also returned if the path doesn’t exist or
is a broken symlink.

@function is_char
@tparam lsh.path self
@treturn[1] lsh.path `self`
@treturn[2] false
]]
function methods.is_char(self)
  local st = self:stat()
  if st and st.ischar then
    return self
  end

  return false
end

--[[- Set extended attribute.
@function setxattr
@tparam lsh.path self
@tparam string name name of the attribute
@tparam string value value of the attribute
@tparam[opt] string flag `"CREATE"` or `"REPLACE"`
@treturn[1] bool `true`
@treturn[2] nil
@treturn[2] string error
]]
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

  return ok
end

--[[- Get extended attribute.
@function getxattr
@tparam lsh.path self
@tparam string name name of the attribute
@treturn[1] string value of the attribute
@treturn[2] nil
@treturn[2] string error
]]
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

--[[- Remove extended attribute.
@function removexattr
@tparam lsh.path self
@tparam string name name of the attribute
@treturn[1] bool `true`
@treturn[2] nil
@treturn[2] string error
]]
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

--[[- List extended attribute.
@function listxattr
@tparam lsh.path self
@treturn[1] table name/value pairs of extended attributes
@treturn[2] nil
@treturn[2] string error
]]
function methods.listxattr(self)
  local res, err = S.listxattr(self.path)
  if err then
    return nil, tostring(err)
  end

  return res
end

--[[- Create a new directory at this given path.

If mode is given, it is combined with the process' `umask`
value to determine the file mode and access flags. If the
path already exists, `nil` with error message is returned.

If parents is `true`, any missing parents of this path are
created as needed; they are created with the default permissions
without taking mode into account (mimicking the POSIX
`mkdir -p` command).

If parents is `false` (the default), a missing parent returns
`nil` and error message.

If exists is `false` (the default), `nil` and error message is
returned if the target directory already exists.

If exists is `true`, file exist errors will be ignored
(same behavior as the POSIX `mkdir -p` command), but only if
the last path component is not an existing non-directory file.

@function mkdir
@tparam lsh.path self
@tparam string mode set mode (default is `0755`)
@tparam[opt] bool parents wether to create parent directories
@tparam[opt] bool exists whether to ignore file exist errors
@treturn[1] bool `true`
@treturn[2] nil
@treturn[2] string error
]]
function methods.mkdir(self, mode, parents, exists)
  if mode and type(mode) ~= 'string' then
    error(err_str:format(2, 'mkdir', 'string or nil', type(mode)), 2)
  else
    mode = '0755'
  end

  if parents then
    local i, pparts = 1, self.parent.parts
    local pparts_len = #pparts
    local path = ""

    -- find missing dir in path
    while i <= pparts_len do
      local p = _M.new(path, pparts[i])

      if not p:exists() then
        break
      end

      if not p:is_dir() then
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

  local ok, err = S.mkdir(self.path, mode)
  if err then
    if err.EXIST and exists then
      return true
    end

    return nil, tostring(err)
  end

  return ok
end

--[[- Remove this directory. The directory must be empty.
@function rmdir
@todo recursive remove
@tparam lsh.path self
@treturn[1] bool `true`
@treturn[2] nil
@treturn[2] string error
]]
function methods.rmdir(self)
  local ok, err = S.rmdir(self.path)
  if not ok then
    return nil, tostring(err)
  end

  return ok
end

local function dir_close(dir)
  if dir.fd then
    dir.fd:close()
    dir.fd = nil
  end
end

local function dir_next(dir)
  if not dir.fd then
    return nil, 'dir ended'
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
      dir.first = true
    end

    d = dir.di()
    if not d then
      dir.di = nil
      if dir.first then
        dir_close(dir)
        return nil
      end
    elseif d.name == '.' or d.name == '..' then
      d = nil
    end

    dir.first = false
  until d

  return d.name
end

--[[- When the path points to a directory, returns function
iterator over the entries of a given directory.

Each time the iterator is called with `dir_obj` it returns a
directory entry, or `nil` if there are no more entries. The
entries are yielded in arbitrary order, and the special
entries `'.'` and `'..'` are not included.
You can also iterate by calling `dir_obj:next()`, and explicitly
close the directory before the iteration finished with
`dir_obj:close()`.
Returns a `nil` and error message if path is not a directory.

@function lsdir
@tparam lsh.path self
@treturn[0] func iterator yielding directory entries
@treturn[0] table dir_obj directory object
@treturn[1] nil
@treturn[1] string error
]]
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

--[[- Updates modified date of the file or creates it.

If mode is given, it is combined with the process' umask value
to determine the file mode and access flags. If the file already
exists, the function succeeds if exists is `true` (and its
modification time is updated to the current time), otherwise
`nil` and error message is returned.

@function touch
@tparam lsh.path self
@tparam[opt] string mode set mode (default is `0666`)
@tparam[opt] bool exists whether to ignore file exist errors
@treturn[1] bool `true`
@treturn[2] nil
@treturn[2] string error
]]
function methods.touch(self, mode, exists)
  if self:exists() then
    if exists then
      S.utime(self.path)
      return true
    end
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

--[[- Remove this file or symbolic link.

If the path points to a directory, use `rmdir` instead.

If missing is `false` (the default), `nil` and error string
is returned if the path does not exist.

If missing is `true`, `file not found` error will be ignored
(same behavior as the POSIX `rm -f` command).

@function unlink
@tparam lsh.path self
@tparam[opt] bool missing wether to error on missing file
@treturn[1] bool `true`
@treturn[2] nil
@treturn[2] string error
]]
function methods.unlink(self, missing)
  local ok, err = S.unlink(self.path)
  if err then
    if err.NOENT and missing then
      return true
    end

    return nil, tostring(err)
  end

  return ok
end

local path_mt = {
  __index = function (t, k)
    if attrs[k] then
      return attrs[k](t)
    end

    return methods[k]
  end,
  __tostring = function(t)
    return t.path
  end,
  --[[- Returns number of components in the path.
  @function __len
  @tparam lsh.path self
  @treturn number number of components
  @usage
  local sh = require 'lsh'

  assert(#sh.path('/etc', 'resolv.conf') == 3)
  ]]
  __len = function(self)
    return #self.parts
  end,
  --[[- Check if paths are identical.
  @function __eq
  @tparam lsh.path l left value
  @tparam lsh.path r right value
  @treturn[1] bool
  @treturn[2] nil
  @treturn[2] string error message
  @usage
  local sh = require 'lsh'

  assert(sh.path('/etc', 'resolv.conf') == sh.path('/etc', 'resolv.conf'))
  ]]
  __eq = function (l, r)
    if type(r) == 'string' then
      return l.parent == r
    elseif type(l) == 'string' then
      return r == l.parent
    end

    return l.path == r.path
  end,
  --[[- Concatinates path with a string or string with a path,
  returning the new joined path instance.
  @function __div
  @tparam lsh.path|string l left value
  @tparam lsh.path|string r right value
  @treturn[1] lsh.path new joined `path` instance
  @treturn[2] nil
  @treturn[2] string error message
  @usage
  local sh = require 'lsh'

  assert(sh.path('/etc'):join(resolv.conf') == sh.path('/etc') / 'resolv.conf')
  ]]
  __div = function(l, r)
    if type(l) == 'table' and l.type and l.type() == 'path' then
      return l:join(r)
    end

    return r:join(l)
  end,
}

--- Functions
-- @section functions

--[[- Constructs a new @{path} instance.
@function new
@tparam ... ... `string`, `number` or @{lsh.path}
@treturn lsh.path new @{path} instance
@usage
local sh = require 'lsh'

sh.path.new('/', 'var')
]]
function _M.new(...)
  local path, err = join(...)
  if err then return nil, err end

  return setmetatable({path = path}, path_mt)
end

--[[- Get current working directory.
@function cwd
@treturn[1] lsh.path @{path} pointing to workidir
@treturn[2] nil
@treturn[2] string error message
@usage
local sh = require 'lsh'

sh.path.cwd()
]]
function _M.cwd()
  local cwd, err = S.getcwd()
  if err then
    return nil, tostring(err)
  end

  return _M.new(cwd)
end

--[[- Get home directory.
@function home
@treturn[1] lsh.path @{path} pointing to `HOME` directory
@treturn[2] nil
@treturn[2] string error message
@usage
local sh = require 'lsh'

sh.path.home()
]]
function _M.home()
  return _M.new(os.getenv('HOME'))
end

local mt = {
  __index = _M,
  --[[- Shorthand for `new`.
  @function __call
  @tparam table _M module table
  @tparam ... ... `string`, `number` or @{lsh.path}
  @treturn lsh.path new @{path} instance
  @usage
  local sh = require 'lsh'

  sh.path('/', 'var')
  ]]
  __call = function(_M, ...)
    return _M.new(...)
  end
}

return setmetatable({}, mt)

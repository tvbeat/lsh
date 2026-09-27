--- File input/output handle.
-- @module lsh.fio.fh

local ffi = require 'ffi'
local S   = require 'syscall'

local tablex  = require 'lsh.tablex'
local stringx = require 'lsh.stringx'

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"

local buf_t = ffi.typeof('char[?]')
local offset_t = ffi.typeof('uint64_t')

local function fh_str(fh)
  -- TODO:
  -- - restore seek position
  -- - check for max lua string size to prevent out of memory
  fh:seek(0)
  local res = {}

  local i = 1
  while true do
    local part = fh:read()
    if part == '' then
      if i > 1 then
        res[i-1] = stringx.chomp(res[i-1])
      end
      break
    end
    res[i] = part
    i = i + 1
  end

  return table.concat(res)
end

--- Fh methods.
-- @section fh
local methods = tablex.new(0, 8)

--[[- Returns the instance type.
@function type
@return the string `"fh"`
@usage
local sh = require 'lsh'

assert(sh.open('/dev/null'):type() == 'fh')
]]
function methods.type()
  return 'fh'
end

--[[- Closes the file handle.
@function close
@tparam lsh.fio.fh self
@treturn[1] bool `true`
@treturn[2] nil
@treturn[2] string error
@usage
local sh = require 'lsh'

assert(sh.open('/dev/null'):close())
]]
function methods.close(self)
  local ok, err = self.fd:close()
  if err then
    return nil, tostring(err)
  end

  return ok
end

--[[- Reads from the file handle into the given buffer.

This low-level interface is for micro-optimizations.
For usual reads, see `read`.

@function read_to_buf
@tparam lsh.fio.fh self
@tparam cdata buf buffer to read into
@tparam number len length of the buffer
@treturn[1] number the number of bytes read into buffer
@treturn[2] nil
@treturn[2] string error
@usage
local sh = require 'lsh'
local ffi = require 'ffi'

local buf_len = 4096
local buf = ffi.new('char[?]', buf_len)

local in_fh = sh.open('in.txt', 'rdonly', 'RUSR')
local out_fh = sh.open('out.txt', {'creat', 'wronly'}, {'RUSR', 'WUSR'})

repeat
  local len = in_fh:read_to_buf(buf, buf_len)
  out_fh:write(buf, len)
until len <= 0
]]
function methods.read_to_buf(self, buf, len)
  if type(buf) ~= 'cdata' then
    error(err_str:format(2, 'read_to_buf', 'cdata', type(buf), 2))
  end
  if type(len) ~= 'number' then
    error(err_str:format(3, 'read_to_buf', 'number', type(len)), 2)
  end

  local offset = self.offset or offset_t(0)
  local res, err = self.fd:pread(buf, len, offset)
  if err then
    return nil, tostring(err)
  end

  self.offset = offset + res

  return res
end

local rlen = S.getpagesize() -- size of default read buffer
local rbuf = buf_t(rlen)

--[[- Reads from the file handle.
@function read
@tparam lsh.fio.fh self
@tparam[opt] number len maximum number of bytes to read
@treturn[1] string the data that was read
@treturn[2] nil
@treturn[2] string error
@usage
local sh = require 'lsh'

local zeros = sh.open('/dev/zero'):read(3)
assert(#zeros == 3)
]]
function methods.read(self, len)
  if len and type(len) ~= 'number' then
    error(err_str:format(2, 'read', 'number', type(len)), 2)
  end
  len = len or rlen

  local tmpbuf = rbuf -- try to reuse allocated buffer
  if len > rlen then
    -- if provided size is bigger than page size allocate
    -- new temporary buffer
    tmpbuf = buf_t(len)
  end

  local res, err = self:read_to_buf(tmpbuf, len)
  if err then
    return nil, tostring(err)
  end

  return ffi.string(tmpbuf, res)
end

--[[- Writes to the file handle.
@function write
@tparam lsh.fio.fh self
@tparam cdata|string buf buffer to write
@tparam[opt] int len length of the buffer
(required if buf is `cdata`)
@treturn[1] bool `true`
@treturn[2] nil
@treturn[2] string error
@usage
local sh = require 'lsh'

assert(sh.open('/dev/null', 'wronly'):write('abc'))

-- advanced usage, passing `cdata` pointers
local ffi = require 'ffi'
local str = 'abc'
local buf = ffi.new('char[?]', #str, str)
assert(sh.open('/dev/null', 'wronly'):write(buf, #str))
]]
function methods.write(self, buf, len)
  local offset = self.offset or offset_t(0)
  local buf_type = type(buf)

  if buf_type == 'string' then
    len = len or #buf
  elseif buf_type == 'cdata' then
    if type(len) ~= 'number' then
      error(err_str:format(3, 'write', 'number', type(len)), 2)
    end
  else
    error(err_str:format(2, 'write', 'string or cdata', buf_type), 2)
  end

  local res, err = self.fd:pwrite(buf, len, offset)
  if err then
    return nil, tostring(err)
  end

  self.offset = offset + res

  return res >= 0
end

--[[- Sets the position for the next read or write.

This interface is not final. It will change in incompatible ways.

@function seek
@tparam lsh.fio.fh self
@tparam number position
@treturn number position
@usage
local sh = require 'lsh'

local position = sh.open('/dev/zero'):seek(3)
]]
function methods.seek(self, position)
  -- TODO
  if type(position) ~= 'number' then
    error(err_str:format(2, 'seek', 'number', type(position)), 2)
  end
  --local cur = self.fd:tell()
  self.offset = offset_t(position)

  return tonumber(self.offset)
end

--[[- Returns an iterator function. Each call returns the next
line from the file handle, without the line ending.
@function lines
@tparam lsh.fio.fh self
@treturn func function iterator
@usage
local sh = require 'lsh'

for line in sh.memfd('foo\nbar'):lines() do
  print(line)
end
--> foo
--> bar
]]
function methods.lines(self)
  --[[ todo
    * implementation is portable and simple to understand
      but very slow, options are to move pointer arithmetic
      to plain C or ditch mmap completely
    * in !GC64 mode we should find address for mmap outside
      of lower 4G to not mess with LuaJIT allocations
    * optional delimiter flag
  ]]
  local nl = string.byte('\n')
  local cr = string.byte('\r')

  local st = self.fd:stat()
  local size = st.size
  -- nothing to mmap
  if size <= 0 then
    return function() end
  end

  -- In case of memfd mmap will only reserve new region of
  -- virtual memory, it does not copy the memory
  local buf, err = S.mmap(0, size, 'read', 'shared', self.fd, 0)
  if not buf then
    error('mmap failed: '..tostring(err))
  end

  buf = ffi.cast('const char*', buf)
  local buf_start, buf_end = buf, buf + size
  ffi.gc(buf, function()
    S.munmap(buf_start, size)
  end)

  return function()
    local count = 0
    while buf <= buf_end do
      local c = buf[0] -- dereference

      if c == nl then -- match UNIX \n
        local ret = ffi.string(buf-count, count)

        buf = buf + 1
        return ret
      end

      if c == cr then -- match Mac OS \r
        local ret = ffi.string(buf-count, count)

        if buf < buf_end then
          local c_next = (buf+1)[0]
          if c_next == nl then -- match Windows \r\n
            buf = buf + 2
            return ret
          end
        end

        buf = buf + 1
        return ret
      end

      if buf == buf_end then -- end of file
        local ret

        if count > 0 then
          ret = ffi.string(buf-count, count) -- return leftovers
        end

        buf = buf + 1
        return ret
      end

      count = count + 1
      buf = buf + 1
    end

    return nil
  end
end

--[[- Returns the file descriptor number.
@function getfd
@tparam lsh.fio.fh self
@treturn number file descriptor number
@usage
local sh = require 'lsh'

print(sh.open('/dev/null'):getfd())
--> 3
]]
function methods.getfd(self)
  return tonumber(self.fd:getfd())
end

--- Functions
-- @section functions
local _M = tablex.new(0, 1)
local fh_mt = {
  __index = methods,
  __tostring = function(t)
    return fh_str(t)
  end,
}

--[[- Constructs a new file handle.

You do not need to call this function directly.
Use @{lsh.memfd} or @{lsh.fio.open}.

@function new
@tparam cdata fd ljsyscall fd
@treturn lsh.fio.fh new `fh` instance
@usage
local sh = require 'lsh'

local fh = sh.memfd()
]]
function _M.new(fd)
  -- TODO: proper check, convert lua file handle
  if type(fd) ~= 'cdata' then
    error(err_str:format(1, 'new', 'cdata', type(fd)), 2)
  end

  return setmetatable({fd = fd}, fh_mt)
end

return _M

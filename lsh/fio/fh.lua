-- fio.fh - file handle

local ffi = require 'ffi'
local S   = require 'syscall'

local tablex = require 'lsh.tablex'

local buf_t = ffi.typeof('char[?]')
local offset_t = ffi.typeof('uint64_t')

local function fh_str(fh)
  -- TODO:
  -- - restore seek position
  -- - check for max lua string size to prevent out of memory
  fh:seek(0)
  local res = {}

  while true do
    local part = fh:read()
    if part == '' then break end
    table.insert(res, part)
  end

  return table.concat(res)
end

local _M = tablex.new(0, 8)
local fh_mt = {
  __index = _M,
  __tostring = function(t)
    return fh_str(t)
  end,
}

function _M.new(fd)
  -- TODO: proper check, convert lua file handle
  assert(type(fd) == 'cdata', 'input must be ljsyscall fd')

  return setmetatable({fd = fd}, fh_mt)
end

-- return 'fh' if input is fh type
function _M.type(self)
  if type(self) ~= 'table' then return nil end
  if getmetatable(self) == fh_mt then
    return 'fh'
  end

  return nil
end

function _M.close(self)
  local ok, err = self.fd:close()
  if err then
    return nil, tostring(err)
  end

  return ok
end

-- write(str)
-- write(buf, len)
function _M.write(self, buf, len)
  local offset = self.offset or offset_t(0)

  if type(buf) == 'cdata' then
    assert(type(len) == 'number')
  else
    buf = tostring(buf)
    len = #buf
  end

  local res, err = self.fd:pwrite(buf, len, offset)
  if err then
    return nil, tostring(err)
  end

  self.offset = offset + res

  return res >= 0
end

local rsize = 4096 -- size of default read buffer
local rbuf = buf_t(rsize)

-- read(size) -> str
-- read(buf, size) -> len
function _M.read(self, buf, size)
  local offset = self.offset or offset_t(0)
  local tmpbuf

  if type(buf) == 'cdata' then
    assert(type(size) == 'number')
  else
    if buf then -- buf is holding size
      assert(type(buf) == 'number')
      size = buf
    end

    tmpbuf = rbuf -- try to reuse allocated buffer
    if size then
      assert(type(size) == 'number')
      if size > rsize then
        -- if provided size is bigger than default allocate new buf
        tmpbuf = buf_t(size)
      end
    else
      size = rsize
    end
  end

  local res, err = self.fd:pread(tmpbuf or buf, size, offset)
  if err then
    return nil, tostring(err)
  end

  self.offset = offset + res

  if tmpbuf then
    return ffi.string(tmpbuf, res)
  end

  return res
end

-- TODO
function _M.seek(self, position)
  assert(type(position) == 'number')
  --local cur = self.fd:tell()
  self.offset = offset_t(position)

  return tonumber(self.offset)
end

-- read line by line, similar to io.lines
--
-- TODO:
--  * implementation is portable and simple to understand
--    but very slow, options are to move pointer arithmetic
--    to plain C or ditch mmap completely
--  * in !GC64 mode we should find address for mmap outside
--    of lower 4G to not mess with LuaJIT allocations
--  * optional delimiter flag
function _M.lines(self)
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

function _M.getfd(self)
  return self.fd:getfd()
end

local mt = {
  __index = _M,
  __call = function(t, fd)
    return _M.new(fd)
  end,
}

return setmetatable({}, mt)

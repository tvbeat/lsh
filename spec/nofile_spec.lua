local S = require 'syscall'
local sh = require 'lsh'

-- open fds kept referenced, so the garbage collector can not close them
local function exhaust_fds()
  local held = {}
  while true do
    local fd = S.memfd_create('', 'cloexec')
    if not fd then break end
    table.insert(held, fd)
  end
  return held
end

describe('nofile limit', function()
  local limit

  before_each(function()
    limit = S.getrlimit('nofile')
    collectgarbage()
    assert(S.setrlimit('nofile', {cur = 64, max = limit.max}))
  end)

  after_each(function()
    collectgarbage()
    assert(S.setrlimit('nofile', {cur = limit.cur, max = limit.max}))
  end)

  it('collects unreferenced handles and retries', function()
    local str = 'aaa1111fffffffffff'
    for _ = 1, 500 do
      local out = assert(sh.cmd('echo', str):output())
      assert.are.equal(str, tostring(out.stdout))
    end
  end)

  it('returns an error from output when no fd is free', function()
    local held = exhaust_fds()
    local out, err = sh.cmd('echo', 1):output()
    assert.is_nil(out)
    assert.are.equal('Too many open files', err)
    assert.is_true(#held > 0)
  end)

  it('runs a child when no fd is free', function()
    local held = exhaust_fds()
    assert.is_true(sh.cmd('true'):run():success())
    assert.is_true(#held > 0)
  end)
end)

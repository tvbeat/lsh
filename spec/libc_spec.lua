local sh = require 'lsh'
local libc = require 'lsh.libc'
local helper = require 'helper'

describe('libc.glob', function()
  local dir

  before_each(function() dir = helper.tmpdir() end)
  after_each(function() helper.rmtree(dir) end)

  it('returns matching paths', function()
    helper.write(dir / 'a.lua', '')
    helper.write(dir / 'b.lua', '')
    helper.write(dir / 'c.txt', '')
    local res = assert(libc.glob(tostring(dir / '*.lua')))
    table.sort(res)
    assert.are.same({tostring(dir / 'a.lua'), tostring(dir / 'b.lua')}, res)
  end)

  it('reports the errno of unreadable directories', function()
    assert(dir:join('open'):mkdir())
    helper.write(dir / 'open' / 'f', '')
    local locked = dir / 'locked'
    assert(locked:mkdir())
    assert(sh.cmd('chmod', '000', locked):run():success())
    finally(function() sh.cmd('chmod', '700', locked):run() end)

    local res, errs = libc.glob(tostring(dir / '*' / '*'))
    assert.are.same({tostring(dir / 'open' / 'f')}, res)
    if errs then -- root can read the directory anyway
      assert.are.same({[tostring(locked)] = 'Permission denied'}, errs)
    end
  end)

  it('returns an empty array when nothing matches', function()
    assert.are.same({}, libc.glob(tostring(dir / '*.none')))
  end)
end)

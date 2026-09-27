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

  it('returns an empty array when nothing matches', function()
    assert.are.same({}, libc.glob(tostring(dir / '*.none')))
  end)
end)

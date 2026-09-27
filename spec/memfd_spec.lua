local sh = require 'lsh'

describe('memfd', function()
  it('reads, writes and seeks', function()
    local memfd = sh.memfd('123')
    assert.are.equal('123', tostring(memfd))

    memfd:write('456789')
    assert.are.equal('123456789', tostring(memfd))
    memfd:seek(0)
    memfd:write('foobar')
    assert.are.equal('foobar789', tostring(memfd))

    memfd:seek(6)
    assert.are.equal('789', memfd:read())
    memfd:seek(0)
    assert.are.equal('foobar789', memfd:read())
  end)

  it('works as stdin of a command', function()
    local out, err = sh.cmd('cat'):stdin(sh.memfd('hello')):output()
    assert.is_nil(err)
    assert.are.equal('hello', tostring(out.stdout))
  end)

  it('splits lines on all line endings', function()
    local memfd = sh.memfd('123\n456\r\n\r\n\n567\nabc\n\na\rab\rfoo')
    local lines = {}
    for line in memfd:lines() do table.insert(lines, line) end
    assert.are.same({'123', '456', '', '', '567', 'abc', '', 'a', 'ab', 'foo'}, lines)
  end)

  it('returns no lines when empty', function()
    local n = 0
    for _ in sh.memfd():lines() do n = n + 1 end
    assert.are.equal(0, n)
  end)
end)

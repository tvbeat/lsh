local sh = require 'lsh'

describe('stringx', function()
  it('splits on whitespace', function()
    assert.are.same({'one', 'two', 'three'}, sh.stringx.split('one two  three'))
  end)

  it('splits on a separator', function()
    assert.are.same({'one ', 'wo  ', 'hree'}, sh.stringx.split('one two  three', 't'))
  end)

  it('limits the number of splits', function()
    assert.are.same({'a', 'b,c'}, sh.stringx.split('a,b,c', ',', 1))
  end)

  it('removes a final newline', function()
    assert.are.equal('abc', (sh.stringx.chomp('abc\n')))
    assert.are.equal('abc', (sh.stringx.chomp('abc')))
  end)
end)

local sh = require 'lsh'

describe('pipeline', function()
  it('connects commands with pipes', function()
    local p = sh.cmd('printf', 'b\\na\\nb\\n') /
              sh.cmd('sort') /
              sh.cmd('uniq', '-c'):stderr('/dev/null') /
              sh.cmd('cat', '-')
    local out = p:output()
    assert.is_true(out.status:success())
    assert.matches('^%s*1 a\n%s*2 b$', tostring(out.stdout))
  end)

  it('builds with add', function()
    local out = sh.pipeline():add(sh.cmd('echo', 123))
                             :add(sh.cmd('tr', '3', 'x'))
                             :output()
    assert.are.equal('12x', tostring(out.stdout))
  end)

  it('returns a status for each process', function()
    local status = sh.pipeline():add(sh.cmd('true'))
                                :add(sh.cmd('false'))
                                :run()
    assert.is_false(status:success())
    assert.are.same({0, 1}, status:codes())
  end)

  it('collects statuses with try_wait', function()
    local children = (sh.cmd('echo', 1) / sh.cmd('cat')):stdout('/dev/null'):spawn()
    local pstatus
    repeat pstatus = children:try_wait() until pstatus
    assert.is_true(pstatus:success())
  end)

  it('captures stderr in output', function()
    local out = sh.pipeline():add(sh.cmd('sh', '-c', 'echo err >&2'))
                             :add(sh.cmd('cat'))
                             :output()
    assert.are.equal('err', tostring(out.stderr))
  end)

  it('rejects a non-pipeline table in children.new', function()
    local children = require 'lsh.pipeline.children'
    assert.has_error(function() children.new(sh.cmd('ls')) end)
  end)

  it('kills all processes', function()
    local children = sh.pipeline():add(sh.cmd('sleep', 10))
                                  :add(sh.cmd('sleep', 10))
                                  :spawn()
    assert.is_true(children:kill('kill'))
    assert.is_false(children:wait():success())
  end)
end)

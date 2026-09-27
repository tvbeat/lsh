local sh = require 'lsh'
local helper = require 'helper'

describe('cmd', function()
  local dir

  before_each(function() dir = helper.tmpdir() end)
  after_each(function() helper.rmtree(dir) end)

  it('clones', function()
    local cmd = sh.cmd('echo', 1):workdir(dir):stdout('/dev/null')
    assert.are.equal(tostring(cmd), tostring(cmd:clone()))
  end)

  it('builds arguments', function()
    local cmd = sh.cmd('echo')
    cmd:args({'1', sh.path('/tmp')})
    assert.are.equal('echo 1 /tmp', tostring(cmd))
    cmd:arg('bla')
    assert.are.equal('echo 1 /tmp bla', tostring(cmd))
  end)

  it('runs a command', function()
    assert.is_true(sh.cmd('true'):run():success())
    assert.is_false(sh.cmd('false'):run():success())
    assert.are.equal(3, sh.cmd('sh', '-c', 'exit 3'):run():code())
  end)

  it('reports a signal as failure', function()
    local status = sh.cmd('sh', '-c', 'kill -9 $$'):run()
    assert.is_false(status:success())
    assert.are.equal(9, status:code())
  end)

  it('does not block in try_wait', function()
    local child = sh.cmd('sleep', 1):spawn()
    assert.is_false(child:try_wait())
    assert(child:kill())
    assert.is_false(child:wait():success())
  end)

  it('returns the same status on each wait', function()
    local child = sh.cmd('true'):spawn()
    local status
    repeat status = child:try_wait() until status
    assert.is_true(status:success())
    assert.are.equal(status, child:wait())
    assert.are.equal(0, child:wait():code())
  end)

  it('exits the child with 127 when exec fails', function()
    local out = sh.cmd('lsh-no-such-program'):output()
    assert.are.equal(127, out.status:code())
    assert.are.equal('lsh-no-such-program: exec: No such file or directory', tostring(out.stderr))
    assert.are.equal('', tostring(out.stdout))
  end)

  it('exits the child with 127 when the workdir is missing', function()
    -- chdir happens before the stdio redirection, so the error goes to the parent stderr
    local status = sh.cmd('true'):workdir(dir / 'none'):run()
    assert.are.equal(127, status:code())
  end)

  it('sets environment variables', function()
    local out = sh.cmd('printenv', 'MYENV'):env({MYENV = 'test'}):output()
    assert.are.equal('test', tostring(out.stdout))
  end)

  it('removes environment variables', function()
    local out = sh.cmd('printenv', 'MYENV'):env({MYENV = 'test'})
                                          :env_remove('MYENV')
                                          :output()
    assert.is_false(out.status:success())
  end)

  it('runs in the working directory', function()
    local out = sh.cmd('pwd'):workdir(dir):output()
    assert.are.equal(tostring(dir), tostring(out.stdout))
  end)

  it('passes 100k arguments', function()
    local cmd = sh.cmd('echo'):stdout('/dev/null')
    for i=1,100000 do cmd:arg(("arg%d"):format(i)) end
    assert.is_true(cmd:run():success())
  end)

  it('redirects stdout and stdin to files', function()
    local file = dir / 'out'
    assert.is_true(sh.cmd('echo', 'hello'):stdout(file):run():success())
    assert.are.equal('hello', helper.read(file))

    local out = sh.cmd('cat'):stdin(file):output()
    assert.are.equal('hello', tostring(out.stdout))
  end)

  it('captures stdout and stderr', function()
    local out = sh.cmd('sh', '-c', 'echo out; echo err >&2'):output()
    assert.are.equal('out', tostring(out.stdout))
    assert.are.equal('err', tostring(out.stderr))
  end)

  describe('argument errors', function()
    it('reports the type of args', function()
      local ok, err = pcall(function() sh.cmd('ls'):args(1) end)
      assert.is_false(ok)
      assert.matches("^spec/cmd_spec.lua:%d+: bad argument #2 to 'args' %(table expected, got number%)", err)
    end)

    it('points to the caller for an invalid args entry', function()
      local ok, err = pcall(function() sh.cmd('ls'):args({{}}) end)
      assert.is_false(ok)
      assert.matches('^spec/cmd_spec.lua:%d+: bad argument #2 at index #1', err)
    end)
  end)
end)

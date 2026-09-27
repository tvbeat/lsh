local sh = require 'lsh'
local S = require 'syscall'
local helper = require 'helper'

local path = sh.path

describe('path', function()
  it('has name, stem and suffixes', function()
    local p = path('/etc', 'resolv.conf')
    assert.are.equal('resolv.conf', (p.name))
    assert.are.equal('resolv', p.stem)
    assert.are.equal('.conf', p.suffix)
    assert.are.same({'.gar', '.tar'}, path('lib.tar.gar').suffixes)
    assert.are.same({}, path('lib').suffixes)
  end)

  it('computes stem', function()
    assert.are.equal('lib.tar', path('lib.tar.gar').stem)
    assert.are.equal('lib', path('lib.tar').stem)
    assert.are.equal('lib', path('lib').stem)
    assert.are.equal('lib', path('/home/user/lib').stem)
  end)

  it('computes parent', function()
    assert.are.equal(path('/bla'), path('/bla/z').parent)
    assert.are.equal(path('.'), path('bla').parent)
    assert.are.equal(path('/'), path('/bla').parent)
  end)

  it('computes parents', function()
    local p = path('/usr/local/bin/lua')
    assert.are.equal(path('/usr/local/bin'), p.parents[1])
    assert.are.equal(path('/usr/local'), p.parents[2])
    assert.are.equal(path('/usr'), p.parents[3])
    assert.are.equal(path('/'), p.parents[4])
    assert.are.equal(path('dev'), path('dev/test').parents[1])
  end)

  it('computes relative_to', function()
    local p = path('/etc/passwd')
    assert.are.equal(path('etc/passwd'), p:relative_to('/'))
    assert.are.equal(path('passwd'), p:relative_to('/etc'))
    assert.are.equal(path(), p:relative_to('/etc/passwd'))
    assert.is_nil(p:relative_to('/usr'))
    assert.is_nil(p:relative_to('/etc/passwd/bla'))
  end)

  it('joins with / and join', function()
    assert.are.equal(path('/etc/nginx/nginx.conf'), path('/etc'):join('nginx', 'nginx.conf'))
    assert.are.equal(path('/etc/resolv.conf'), path('/etc') / 'resolv.conf')
  end)

  describe('on the filesystem', function()
    local dir

    before_each(function()
      dir = helper.tmpdir()
      S.umask(tonumber('022', 8))
    end)
    after_each(function() helper.rmtree(dir) end)

    local function mode(p)
      return p:stat().mode % 512
    end

    it('changes the working directory', function()
      local cwd = path.cwd()
      finally(function() assert(cwd:chdir()) end)
      assert(dir:chdir())
      assert.are.equal(dir, path.cwd())
    end)

    it('creates and removes directories', function()
      local d = dir / 'a' / 'b'
      assert.is_nil((d:mkdir()))
      assert.is_true(d:mkdir(nil, true))
      assert(d:is_dir())
      assert.is_nil((d:mkdir()))
      assert.is_true(d:mkdir(nil, false, true))

      assert(d:rmdir())
      assert.is_false(d:exists())
      assert.is_false(d:is_dir())
    end)

    it('respects mode in mkdir', function()
      S.umask(0)
      assert(dir:join('m'):mkdir('0700'))
      assert.are.equal(tonumber('700', 8), mode(dir / 'm'))
      assert(dir:join('d'):mkdir())
      assert.are.equal(tonumber('755', 8), mode(dir / 'd'))
    end)

    it('respects mode in touch', function()
      S.umask(0)
      assert(dir:join('t'):touch('0600'))
      assert.are.equal(tonumber('600', 8), mode(dir / 't'))
      assert(dir:join('d'):touch())
      assert.are.equal(tonumber('666', 8), mode(dir / 'd'))
    end)

    it('touches and unlinks files', function()
      local f = dir / 'f'
      assert(f:touch())
      assert(f:is_file())
      assert.is_nil((f:touch()))
      assert.is_true(f:touch(nil, true))

      assert(f:unlink())
      assert.is_nil((f:unlink()))
      assert.is_true(f:unlink(true))
    end)

    it('detects symbolic links', function()
      assert(S.symlink(tostring(dir), tostring(dir / 'lnk')))
      assert(dir:join('lnk'):is_link())
      assert.is_false(dir:is_link())
      assert.is_false(dir:join('none'):is_link())
    end)

    it('globs and lists directories', function()
      helper.write(dir / 'a.lua', '')
      helper.write(dir / 'b.txt', '')

      local res = assert(dir:glob('*.lua'))
      assert.are.same({dir / 'a.lua'}, res)

      local names = {}
      for name in dir:lsdir() do table.insert(names, name) end
      table.sort(names)
      assert.are.same({'a.lua', 'b.txt'}, names)
    end)
  end)
end)

local sh = require 'lsh'

--
print "-- cmd clone --"
--
do
  local cmd = sh.cmd('echo', 1):workdir('/tmp')
                               :stdout('/dev/null')
  local cmd2 = cmd:clone()

  -- are we the same on string level ?
  assert(tostring(cmd) == tostring(cmd2))
end

--
print "-- cmd manipulation --"
--

do
  local cmd = sh.cmd('echo')
  cmd:args({'1', sh.path('/tmp')})
  assert(tostring(cmd) == 'echo 1 /tmp')
  cmd:arg('bla')
  assert(tostring(cmd) == 'echo 1 /tmp bla')
end

--
print "-- exec simple --"
--

do
  local status = sh.cmd('echo', '"blabla""', 1):run()
  assert(status:success())
end

--
print "-- exec simple status --"
--
do
  local child = sh.cmd('echo', 1):workdir('/tmp')
                                 :stdout('/dev/null')
                                 :spawn()

  -- we should be faster than `echo` here, so try_wait should return `false`
  assert(child:try_wait() == false)
  assert(child:wait())
end

--
print "-- exec status wait --"
--
do
  local child = sh.cmd('echo', 1):workdir('/tmp')
                                 :stdout('/dev/null')
                                 :spawn()

  local status
  repeat
    status = child:try_wait()
  until status

  assert(status:success())

  -- double wait
  assert(child:wait())
  assert(child:wait():code() == 0)
end

--
print "\n-- exec simple env --"
--

local output = sh.cmd('printenv', 'MYENV'):env({MYENV = 'test'})
                                          :output()

assert(("%s"):format(output.stdout) == 'test')

--
print "\n-- exec simple workdir --"
--

local status = sh.cmd('cat', '1/cmdline'):workdir('/proc')
                                         :stdout('/dev/null')
                                         :stderr(io.stdout)
                                         :run()
assert(status:success())

--
print "\n-- exec 100k args --"
--
local cmd = sh.cmd('echo'):workdir('/tmp')
                          :stdout('/dev/null')
for i=1,100000 do cmd:arg(("arg%d"):format(i)) end
local status = cmd:run()
assert(status:success())

--
print "\n-- exec redirect stdout --"
--

local status = sh.cmd('cat', '1/cmdline'):workdir('/proc')
                                         :stdout('/tmp/out')
                                         :run()
assert(status:success())

local output = sh.cmd('cat', '-'):workdir('/tmp')
                                 :stdin('/tmp/out')
                                 :output()

local fh = sh.open('/tmp/out', 'rdonly', 'RUSR')
assert(tostring(output.stdout) == tostring(fh))

--
print "\n-- exec redirect stdin --"
--

local output = sh.cmd('cat'):stdin('/proc/1/cmdline')
                            :output()
assert(#tostring(output.stdout) >= 1)

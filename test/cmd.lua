local sh = require 'lsh'
local tablex = require 'lsh.tablex'

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


local c = {'echo', 1}
local o = {workdir = '/tmp', stdout = '/dev/null'}

--
print "-- exec simple --"
--

local res = sh.cmd('echo', '"blabla""', 1):run()

print(res)

--
print "-- exec simple status --"
--
do
  local res = sh.cmd('echo', 1):workdir('/tmp')
                               :stdout('/dev/null')
                               :exec()

  -- we are faster than cmd here, so status should return alive -> true
  assert(res.status.alive)
  assert(res:wait())
end

--
print "-- exec status wait --"
--
do
  local res = sh.cmd('echo', 1):workdir('/tmp')
                               :stdout('/dev/null')
                               :exec()

  local status
  repeat
    status = res.status
  until not status.alive

  assert(res:wait().exit_status)

  -- double wait
  assert(res:wait())

  assert(res.status.exit_status)
  assert(res.exit_status)
end

--
print "\n-- exec simple env --"
--

local res = sh.cmd('printenv', 'MYENV'):env({MYENV = 'test'})
                                       :stdout(sh.memfd())
                                       :run()

assert(("%s"):format(res.stdout) == 'test')

--
print "\n-- exec simple workdir --"
--

local res = sh.cmd('cat', '1/cmdline'):workdir('/proc')
                                      :stdout('/dev/null')
                                      :stderr(io.stdout)
                                      :run()
assert(res.exit_status == 0)

--
print "\n-- exec 100k args --"
--
local cmd = sh.cmd('echo'):workdir('/tmp')
                          :stdout('/dev/null')
for i=1,100000 do cmd:append(("arg%d"):format(i)) end
local res = cmd:run()
assert(res.exit_status == 0)

--
print "\n-- exec redirect stdout --"
--

local res = sh.cmd('cat', '1/cmdline'):workdir('/proc')
                                      :stdout('/tmp/out')
                                      :run()
assert(res.exit_status == 0)

local res = sh.cmd('cat', '-'):workdir('/tmp')
                              :stdin('/tmp/out')
                              :stdout(sh.memfd())
                              :run()

local fh = sh.open('/tmp/out', 'rdonly', 'RUSR')
assert(tostring(res.stdout) == tostring(fh))

--
print "\n-- exec redirect stdin --"
--

local res = sh.cmd('cat'):stdin('/proc/1/cmdline')
                         :stdout(sh.memfd())
                         :run()
assert(#tostring(res.stdout) >= 1)

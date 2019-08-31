local sh = require 'lsh'
local tablex = require 'lsh.tablex'

local c = {'echo', 1}
local o = {workdir = '/tmp', stdout = '/dev/null'}

--
print "-- exec simple --"
--

local res = sh.exec({'echo', '"blabla""', 1}):wait()

print(res)

--
print "-- exec simple status --"
--
do
  local res = sh.exec(c, o)

  local status = res:status()
  -- we are faster than cmd here, so status should return alive -> true
  assert(status.alive)
  assert(res:wait())
end

--
print "-- exec status wait --"
--
do
  local res = sh.exec(c, o)

  local status
  repeat
    status = res:status(true)
  until not status.alive

  -- double wait
  assert(res:status(true).exit_status)

  assert(status.exit_status)
  assert(res.exit_status)
end

--
print "\n-- exec succeed --"
--

assert(pcall(function () sh.exec({'true'}):succeed() end))

print(pcall(function () sh.exec({'false'}):succeed() end))
assert(not pcall(function () sh.exec({'false'}):succeed() end))


--
print( "\n-- exec function --" )
--

local res = sh.exec(function()
  print("hello")
end):wait()

print(res)

--
print "\n-- exec simple env --"
--

local res = sh.exec({'printenv', 'MYENV'}, {env = {MYENV = 'test'}}):wait()

print(res)

--
print "\n-- exec simple workdir --"
--

local res = sh.exec({'cat', '1/cmdline'}, {workdir = '/proc' , stdout = io.stderr}):wait()
print()
print(res)

--
print "\n-- exec 100k args --"
--
local cmd = {'echo'}
for i=1,100000 do cmd[i+1] = ("arg%d"):format(i) end
local res = sh.exec(cmd, {workdir = '/tmp', stdout = '/dev/null'}):wait()
assert(res.exit_status == 0)

--
print "\n-- exec redirect stdout --"
--

local res = sh.exec({'cat', '1/cmdline'}, {workdir = '/proc', stdout = '/tmp/out'}):wait()
print(res)
local res = sh.exec({'cat', 'out'}, {workdir = '/tmp'}):wait()
print()
print(res)

--
print "\n-- exec redirect stdin --"
--

local res = sh.exec({'cat'}, {stdin = '/proc/1/cmdline'}):wait()
print()
print(res)

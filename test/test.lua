local sh = require 'lsh'

--
print "-- exec simple --"
--

local res = sh.exec({'echo', '"blabla""'}):wait()

print(res)

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

local res = sh.exec({'cat', '1/cmdline'}, {workdir = '/proc' }):wait()
print()
print(res)

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

--
print "\n-- pipeline --"
--

local p = sh.pipeline()

p:add({"ls", "-al", "./*.lua", './????/*.lua', })
 :add({"sort"})
 :add(function()
   for ln in io.stdin:lines() do
     print("lua: ", ln)
   end
 end)
 :add({"uniq", "-c"}, { stderr = fd })
 :add({"cat", "-"})

p:exec()

print(p)

p:wait()

print(p)

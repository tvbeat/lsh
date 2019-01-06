local sh = require 'lsh'

--
print "-- pipeline --"
--

local p = sh.pipeline()

p:add({"ls", "-al", "./*.lua", './????/*.lua', })
 :add({"sort"})
 :add(function()
   for ln in io.stdin:lines() do
     print("lua: ", ln)
   end
 end)
 :add({"uniq", "-c"}, { stderr = io.stdout })
 :add({"cat", "-"})

p:exec()

print(p)

p:wait()

print(p)

--
print "\n-- pipeline status--"
--

do
  local p = sh.pipeline()

  p:add({"ls", "-al", "./*.lua", './????/*.lua', })
   :add({"sort"})
   :add(function()
     for ln in io.stdin:lines() do
       print("lua: ", ln)
     end
   end)
   :add({"uniq", "-c"}, { stderr = io.stdout })
   :add({"cat", "-"}, { stdout = '/dev/null' })

  p:exec()

  local pstatus
  repeat
    pstatus = p:status()
    --for _, cs in ipairs(pstatus) do
    --  print(cs.pid, cs.exit_status)
    --end
  until not pstatus.alive

  print(p)

  p:wait()

  print(p)
end

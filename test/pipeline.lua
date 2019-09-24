local sh = require 'lsh'

--
print "-- pipeline --"
--

local p = sh.pipeline()

p:add("ls", "-al", "./*.lua", './????/*.lua')
 :add("sort")
 :add(sh.cmd("uniq", "-c"):stderr('/dev/null'))
 :add("cat", "-")

local res = p:run()

print(p)

res:wait()

print(res)

--
print "\n-- pipeline status--"
--

do
  local p = sh.pipeline()

  p:add("ls", "-al", "./*.lua", './????/*.lua')
   :add("sort")
   :add(sh.cmd("uniq", "-c"):stderr(io.stdout))
   :add(sh.cmd("cat", "-"):stdout('/dev/null'))

  local res = p:exec()

  local pstatus
  repeat
    pstatus = res.status
--    for _, cs in ipairs(pstatus) do
--      print(cs.pid, cs.exit_status)
--    end
  until not pstatus.alive

  print(p)

  res:wait()

  print(res)
end

local sh = require 'lsh'

-- exec --

local res = sh.exec({'echo', '"blabla""'}):wait()

print(res)


res = sh.exec(function()
  print("hello")
end):wait()

print(res)


-- pipeline --

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

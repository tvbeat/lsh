local sh = require 'lsh'

local res = sh.exec({'echo', '"blabla""'}):wait()

print(res)

local p = sh.pipeline()

p:add({"ls", "-al", "./*.lua", './????/*.lua', })
 :add({"sort"})
 :add({"uniq", "-c"}, { stderr = fd })
 :add({"cat", "-"})

p:exec()

print(p)

p:wait()

print(p)

local sh = require 'luash'

local p = sh.pipeline()

p:add({"ls", "-al", "./*.lua", './????/*.lua', })
 :add({"sort"})
 :add({"uniq", "-c"}, { stderr = fd })
 :add({"cat"})

p:exec({wait = true})

print(p)

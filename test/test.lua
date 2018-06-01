local sh = require 'luash'

local p = sh.pipeline()

p:add({"ls", "-al"})
 :add({"sort"})
 :add({"uniq", "-c"}, { stderr = fd })
 :add({"cat"})

p:exec({wait = false})

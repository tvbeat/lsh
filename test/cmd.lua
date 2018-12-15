local sh = require 'lsh'
local tablex = require 'lsh.tablex'

local c = {'echo', 1}
local o = {workdir = '/tmp', stdout = '/dev/null'}

local c_nested = {'parallel', '--no-notice', '-k', '-j6', {'zcat', '{}', '|', 'jq', '-c', {'.[]', '|', '.select(.id)'}}}

--
print "-- cmd deepcopy --"
--
do
  local cmd = sh.cmd(c, o)

  table.insert(c, 2)
  o.stdin = '/dev/null'

  assert(cmd.cmd[3] == nil)
  table.remove(c) -- clean globals

  assert(cmd.opt.stdin == nil)
  o.stdin = nil -- clean globals
end

--
print "-- cmd clone --"
--
do
  local cmd  = sh.cmd(c, o)
  local cmd2 = cmd:clone()

  -- are we the same ?
  assert(tostring(cmd) == tostring(cmd2))

  -- quick deepcopy check
  table.insert(cmd.cmd, 'ha2')
  cmd.opt.stdin = '/dev/null'

  assert(cmd2.cmd[3] == nil)
  assert(cmd2.opt.stdin == nil)
end

--
print "-- cmd nested --"
--
do
  local cmd = sh.cmd(c_nested, o)
  local out = "parallel --no-notice -k -j6 'zcat {} | jq -c '.[] | .select(.id)''"

  assert(tostring(cmd) == out)
end

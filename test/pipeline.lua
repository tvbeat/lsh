local sh = require 'lsh'

--
print "-- pipeline --"
--
do
  local p = sh.cmd("ls"):arg("-al")
                        :args(sh.path('.'):glob('*.lua'))
                        :args(sh.path('.'):glob('????/*.lua')) /
            sh.cmd("sort") /
            sh.cmd("uniq", "-c"):stderr('/dev/null') /
            sh.cmd("cat", "-")

  local status = p:run()
  assert(status:success())
end

--
print "\n-- pipeline status--"
--

do
  local p = sh.cmd("ls"):arg("-al")
                        :args(sh.path('.'):glob('*.lua'))
                        :args(sh.path('.'):glob('????/*.lua')) /
            sh.cmd("sort") /
            sh.cmd("uniq", "-c"):stderr(io.stdout) /
            sh.cmd("cat", "-"):stdout('/dev/null')

  local children = p:spawn()

  local pstatus
  repeat
    pstatus = children:try_wait()
  until pstatus

  print(p)
  assert(pstatus:success())
end

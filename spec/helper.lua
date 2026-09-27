local sh = require 'lsh'

local _M = {}

-- mktemp respects TMPDIR, so this also works inside the nix build sandbox
function _M.tmpdir()
  local out = assert(sh.cmd('mktemp', '-d'):output())
  assert(out.status:success())
  return sh.path(tostring(out.stdout))
end

function _M.rmtree(p)
  assert(sh.cmd('rm', '-rf', p):run():success())
end

function _M.write(p, content)
  local fh = assert(sh.open(tostring(p), {'creat', 'wronly', 'trunc'}, {'RUSR', 'WUSR'}))
  assert(fh:write(content))
  assert(fh:close())
end

function _M.read(p)
  local fh = assert(sh.open(tostring(p), 'rdonly'))
  local res = tostring(fh)
  fh:close()
  return res
end

return _M

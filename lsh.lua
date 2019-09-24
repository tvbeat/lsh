local tablex = require 'lsh.tablex'

-- lsh module
local _M = tablex.new(0, 9)
_M._VERSION = 'lsh 0.2.0'

-- submodules
_M.cmd      = require 'lsh.cmd'
_M.memfd    = require 'lsh.memfd'
_M.path     = require 'lsh.path'
_M.pipeline = require 'lsh.pipeline'
_M.stringx  = require 'lsh.stringx'
_M.tablex   = tablex

local fio = require 'lsh.fio'
-- fio methods
_M.open = fio.open

local time = require 'lsh.time'
-- time methods
_M.sleep = time.sleep

return _M

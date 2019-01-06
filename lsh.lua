local tablex = require 'lsh.tablex'

-- lsh module
local _M = tablex.new(0, 9)
_M._VERSION = '0.1.0'

-- submodules
_M.cmd      = require 'lsh.cmd'
_M.exec     = require 'lsh.exec'
_M.memfd    = require 'lsh.memfd'
_M.pipeline = require 'lsh.pipeline'
_M.tablex   = tablex

local fio = 'lsh.fio'
-- fio methods
_M.open = fio.open
_M.path = fio.path

local time = 'lsh.time'
-- time methods
_M.sleep = time.sleep

return _M

local tablex = require 'lsh1.tablex'

-- lsh module
local _M = tablex.new(0, 10)
_M._VERSION = '0.1.0'

-- submodules
_M.cmd      = require 'lsh1.cmd'
_M.exec     = require 'lsh1.exec'
_M.memfd    = require 'lsh1.memfd'
_M.path     = require 'lsh1.path'
_M.pipeline = require 'lsh1.pipeline'
_M.stringx  = require 'lsh1.stringx'
_M.tablex   = tablex

local fio = require 'lsh1.fio'
-- fio methods
_M.open = fio.open

local time = require 'lsh1.time'
-- time methods
_M.sleep = time.sleep

return _M

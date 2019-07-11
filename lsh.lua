--- lsh module
-- @module lsh


local tablex = require 'lsh.tablex'

-- lsh module
local _M = tablex.new(0, 10)
_M._VERSION = '0.1.0'

-- submodules

--- cmd
_M.cmd      = require 'lsh.cmd'

--- exec
_M.exec     = require 'lsh.exec'

--- memfd
_M.memfd    = require 'lsh.memfd'

--- pipeline
_M.pipeline = require 'lsh.pipeline'

--- stringx
_M.stringx  = require 'lsh.stringx'

--- tablex
_M.tablex   = tablex

local fio = require 'lsh.fio'

-- fio methods

--- @{lsh.fio.open}
_M.open = fio.open

--- @{lsh.fio.path}
_M.path = fio.path

local time = require 'lsh.time'

-- time methods

--- @{lsh.time.sleep}
_M.sleep = time.sleep

return _M

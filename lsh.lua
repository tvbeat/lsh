--- lsh module
-- @module lsh


local tablex = require 'lsh.tablex'

-- lsh module
local _M = tablex.new(0, 9)
_M._VERSION = 'lsh 0.2.0'

-- submodules

--- @{lsh.cmd} create and manupulate commands and arguments.
_M.cmd = require 'lsh.cmd'

--- @{lsh.memfd} in-memory anonymous file
_M.memfd    = require 'lsh.memfd'

--- @{lsh.path} create and manipulate filesystem paths
_M.path = require 'lsh.path'

--- @{lsh.pipeline} command pipeline
_M.pipeline = require 'lsh.pipeline'

--- @{lsh.stringx} string extensions
_M.stringx = require 'lsh.stringx'

--- @{lsh.tablex} table extensions
_M.tablex = tablex

-- file methods
local fio = require 'lsh.fio'

--- @{lsh.fio.open}
_M.open = fio.open

-- time methods
local time = require 'lsh.time'

--- @{lsh.time.sleep}
_M.sleep = time.sleep

return _M

--[[- The lsh, powerful lua shell scripting toolbelt.
@author Luka Blašković <lblasc at tvbeat.com>
@copyright 2018-2021
@module lsh
]]

local tablex = require 'lsh.tablex'

local _M = tablex.new(0, 9)
--- module version
_M._VERSION = 'lsh 0.3.0'

_M.cmd      = require 'lsh.cmd'
_M.memfd    = require 'lsh.memfd'
_M.path     = require 'lsh.path'
_M.pipeline = require 'lsh.pipeline'
_M.stringx  = require 'lsh.stringx'
_M.tablex   = tablex

local fio = require 'lsh.fio'
_M.open = fio.open

local time = require 'lsh.time'
_M.sleep = time.sleep

return _M

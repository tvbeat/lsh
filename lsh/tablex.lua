-- tablex - table extensions
--
-- source based on tarantool (2.1): src/lua/table.lua
--

local type, pairs = type, pairs
local getmetatable, setmetatable = getmetatable, setmetatable
local tablex = table

local function table_deepcopy_internal(orig, cyclic)
  cyclic = cyclic or {}
  local copy = orig
  if type(orig) == 'table' then
    local mt, copy_function = getmetatable(orig), nil
    if mt then copy_function = mt.__copy end
    if copy_function == nil then
      copy = {}
      if cyclic[orig] ~= nil then
        copy = cyclic[orig]
      else
        cyclic[orig] = copy
        for orig_key, orig_value in pairs(orig) do
          local key = table_deepcopy_internal(orig_key, cyclic)
          copy[key] = table_deepcopy_internal(orig_value, cyclic)
        end
        if mt ~= nil then setmetatable(copy, mt) end
      end
    else
      copy = copy_function(orig)
    end
  end
  return copy
end

--- Deepcopy lua table (all levels)
-- Supports __copy metamethod for copying custom tables with metatables
-- @function deepcopy
-- @table         inp  original table
-- @shallow[opt]  sep  flag for shallow copy
-- @returns            table (copy)
local function table_deepcopy(orig)
  return table_deepcopy_internal(orig, nil)
end

--- Copy any table (only top level)
-- Supports __copy metamethod for copying custom tables with metatables
-- @function copy
-- @table         inp  original table
-- @shallow[opt]  sep  flag for shallow copy
-- @returns            table (copy)
local function table_shallowcopy(orig)
  local copy = orig
  if type(orig) == 'table' then
    local mt, copy_function = getmetatable(orig), nil
    if mt then copy_function = mt.__copy end
    if copy_function == nil then
      copy = {}
      for orig_key, orig_value in pairs(orig) do
        copy[orig_key] = orig_value
      end
      if mt ~= nil then setmetatable(copy, mt) end
    else
      copy = copy_function(orig)
    end
  end
  return copy
end

local ok, table_new = pcall(require, "table.new")
if not ok or type(table_new) ~= "function" then
  table_new = function(narr, nrec) return {} end
end

tablex.copy     = table_shallowcopy
tablex.deepcopy = table_deepcopy
tablex.new      = table_new

return tablex

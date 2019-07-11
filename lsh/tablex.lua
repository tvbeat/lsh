--- table extensions
-- @module lsh.tablex

local type, pairs = type, pairs
local getmetatable, setmetatable = getmetatable, setmetatable
local _M = table

-- based on tarantool (2.1): src/lua/table.lua
local function table_deepcopy(orig, cyclic)
  cyclic = cyclic or {}
  local copy = orig
  if type(orig) == 'table' then
    copy = {}
    if cyclic[orig] ~= nil then
      copy = cyclic[orig]
    else
      cyclic[orig] = copy
      for orig_key, orig_value in pairs(orig) do
        local key = table_deepcopy_internal(orig_key, cyclic)
        copy[key] = table_deepcopy_internal(orig_value, cyclic)
      end
      local mt = getmetatable(orig)
      if mt ~= nil then setmetatable(copy, mt) end
    end
  end

  return copy
end

-- based on tarantool (2.1): src/lua/table.lua
local function table_shallowcopy(orig)
  local copy = orig
  if type(orig) == 'table' then
    copy = {}
    for orig_key, orig_value in pairs(orig) do
      copy[orig_key] = orig_value
    end
    local mt = getmetatable(orig)
    if mt ~= nil then setmetatable(copy, mt) end
  end

  return copy
end

local ok, table_clone = pcall(require, "table.clone")
if not ok or type(table_clone) ~= "function" then
  table_clone = function(tab, deep)
    if deep then
      return table_deepcopy_internal(tab, nil)
    end

    return table_shallowcopy(tab)
  end
end

local ok, table_new = pcall(require, "table.new")
if not ok or type(table_new) ~= "function" then
  table_new = function(narr, nrec) return {} end
end


--- clone table
-- @function clone
-- @return table
_M.clone = table_clone

--- new table
-- @function new
-- @return table
_M.new   = table_new

return _M

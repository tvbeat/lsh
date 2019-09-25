-- tablex - table extensions

local type, pairs = type, pairs
local getmetatable, setmetatable = getmetatable, setmetatable

local err_str = "bad argument #%d to '%s' (%s expected, got %s)"

local ok, table_new = pcall(require, 'table.new')
if not ok or type(table_new) ~= 'function' then
  table_new = function(narr, nrec) return {} end
end

local _M = table_new(0, 7)

_M.new = table_new

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
        local key = table_deepcopy(orig_key, cyclic)
        copy[key] = table_deepcopy(orig_value, cyclic)
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

-- todo: OpenResty table.clone extension for now doesn't
-- support deep copy and shallow copy doesn't copy metatable
--local ok, table_clone = pcall(require, 'table.clone')
local table_clone = function(tbl, deep)
  if type(tbl) ~= 'table' then
    error(err_str:format(1, 'clone', 'table', type(tbl)), 2)
  end

  if deep then
    return table_deepcopy(tbl)
  end

  return table_shallowcopy(tbl)
end

_M.clone = table_clone

local ok, table_clear = pcall(require, 'table.clear')
if not ok then
  table_clear = function(tbl)
    for k, _ in pairs(tbl) do
      tbl[k] = nil
    end
  end
end

_M.clear = table_clear

local ok, table_pack = pcall(require, 'table.pack')
if not ok or type(table_pack) ~= 'function' then
  table_pack = function(...)
    return { n = select('#', ...), ... }
  end
end

_M.pack = table_pack

local ok, table_isempty = pcall(require, 'table.isempty')
if not ok or type(table_isempty) ~= 'function' then
  table_isempty = function(tbl)
    if type(tbl) ~= 'table' then
      error(err_str:format(1, 'isempty', 'table', type(tbl)), 2)
    end

    return (next(tbl) == nil)
  end
end

_M.isempty = table_isempty

local ok, table_isarray = pcall(require, 'table.isarray')
if not ok or type(table_isarray) ~= 'function' then
  table_isarray = function(tbl)
    if type(tbl) ~= 'table' then
      error(err_str:format(1, 'isarray', 'table', type(tbl)), 2)
    end

    -- check if all the table keys are numerical
    for k, _ in pairs(tbl) do
      if type(k) ~= 'number' then
        return false
      end
    end

    return true
  end
end

_M.isarray = table_isarray

local ok, table_nkeys = pcall(require, 'table.nkeys')
if not ok or type(table_nkeys) ~= 'function' then
  table_nkeys = function(tbl)
    if type(tbl) ~= 'table' then
      error(err_str:format(1, 'nkeys', 'table', type(tbl)), 2)
    end

    local count = 0
    for _ in pairs(tbl) do
      count = count + 1
    end

    return count
  end
end

_M.nkeys = table_nkeys

return _M

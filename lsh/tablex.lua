--- table extensions
-- TODO describe how to use, see examples
-- @module lsh.tablex

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

--- clone table
-- @tparam table self table to clone
-- @tparam ?bool deep wether to deep clone, default is no
-- @treturn table clone of `self`
-- @raise error when argument is not a table
_M.clone = function(self, deep)
  return table_clone(self, deep)
end

local ok, table_clear = pcall(require, 'table.clear')
if not ok then
  table_clear = function(tbl)
    for k, _ in pairs(tbl) do
      tbl[k] = nil
    end
  end
end

--- clear table, set all keys to `nil`
-- @tparam table self table to clear
-- @treturn table `self`, cleared
-- @raise error when argument is not a table
_M.clear = function(self)
  return table_clear(self)
end

local ok, table_pack = pcall(require, 'table.pack')
if not ok or type(table_pack) ~= 'function' then
  table_pack = function(...)
    return { n = select('#', ...), ... }
  end
end

--- pack arguments into table
-- @param ... values to put into table
-- @treturn table with values
-- @raise error when argument is not a table
_M.pack = function(...)
  return table_pack(...)
end

local ok, table_isempty = pcall(require, 'table.isempty')
if not ok or type(table_isempty) ~= 'function' then
  table_isempty = function(tbl)
    if type(tbl) ~= 'table' then
      error(err_str:format(1, 'isempty', 'table', type(tbl)), 2)
    end

    return (next(tbl) == nil)
  end
end

--- check if table is empty
-- @tparam table self
-- @treturn[0] bool wether argument is a table with 0 keys
_M.isempty = function(self)
  return table_isempty(self)
end

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

--- check wether table is an array
-- @tparam table self
-- @treturn bool wether argument is a table where all keys are numeric
-- @raise error when argument is not a table
_M.isarray = function(self)
  return table_isarray(self)
end

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

--- get the number of keys in a table
-- @tparam table self
-- @treturn int number of keys in `self`
-- @raise error when argument is not a table
_M.nkeys = function(self)
  return table_nkeys(self)
end

return _M

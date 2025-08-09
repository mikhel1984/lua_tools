--[[  matching.lua

Pattern matching algorithm for lists.
Use if/else workflow as a main syntax construction.

2025, Stanislav Mikhel]]


-- Define range of elements.
local mt_range = {}

-- Define one or finit number of elements.
local mt_var = {}
mt_var.__index = mt_var

--- Use multiplication for differen cases
mt_var.__mul = function (a, b)
  if getmetatable(a) == mt_var then
    if getmetatable(b) == mt_var then
      -- _*_ : make range
      return setmetatable({}, mt_range)
    elseif type(b) == "number" and b > 0 then
      -- _*N or N*_ : limit number of elements
      return setmetatable({math.floor(b)}, mt_var)
    end
  elseif type(a) == "number" then
    return mt_var.__mul(b, a)
  end
  error "unexpected argument"
end

-- Matching logic
local matching = {}

-- Single stub.
matching.VAR = setmetatable({1}, mt_var)

--- Compare two lists.
--  @param src Source list.
--  @param pattern List with pattern to match.
--  @return true when matching complete successfully.
local function _match (src, pattern)
  local i, j = 1, 1
  repeat
    local p = pattern[j]
    -- check special cases
    local mt = getmetatable(p)
    if mt == mt_var then
      -- skip 1 or specific number
      i, j = i+p[1], j+1
    elseif mt == mt_range then
      -- skip 0 or more
      if j == #pattern then return true end
      j, p = j+1, pattern[j+1]  -- get next
      local found = false
      repeat
        -- looking for equal element
        local s = src[i]
        if s == p or 
           type(s) == "table" and type(p) == "table" and _match(s, p) 
        then
          found = true
        else
          i = i+1
        end
      until found or i > #src
      if not found then return false end
      i, j = i+1, j+1
    else
      -- compare directly
      local s = src[i]
      if s == p or
         type(s) == "table" and type(p) == "table" and _match(s, p)
      then
        i, j = i+1, j+1
      else
        return false
      end
    end
  until i > #src or j > #pattern
  return i == (#src+1) and j == (#pattern+1)
end

--- Constructor for matching.
--  @param src Source list.
--  @return function f(pattern) -> bool
matching.make = function (src)
  assert(type(src) == "table", "table expected")
  return function (pattern)
    assert(type(pattern) == "table", "table expected")
    return _match(src, pattern)
  end
end


--[[  Example ]]
if arg[0] == "matching.lua"
then 

local _ = matching.VAR
-- source list
local src = {1, 2, {'a', 'b', 'c'}, 4}

-- usage
local match = matching.make(src)   -- make function for matching

if     match {1, 2, {'a', 'b', 'c'}, 4} then print "all elements"
elseif match {_, 2, _, 4}               then print "stub single elements"
elseif match {_*2, {_*3}, 4}            then print "stub finite sequence"
elseif match {1, 2, _*_}                then print "stub 0 or more elements"
elseif match {_*_, {_*_, 'b', 'c'}, 4}  then print "stub in different places"
else 
  print "pattern not found"
end


--[[  Make library  ]]
else
  return matching
end

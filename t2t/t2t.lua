--[[		t2t.lua 

Tree-like graph representation in the style of Linux 'pstree'.
 
2022, Stanislav Mikhel ]]

--- Unicode components of a tree
local unicode = {
  v = ' │ ', r = ' ├─', h = '───', u = ' └─', d = '─┬─', e = '   ',
}

--- ASCII components of a tree
local ascii = {
  v = ' | ', r = ' +-', h = '---', u = ' *-', d = '-+-', e = '   ',
}

--- Highlight temropary generated tables
local _marker = {}

--- Check if the object is a table
--  @param t Object to check
--  @return true for tables
local function istable(t)  
  local mt = getmetatable(t)
  return type(t) == 'table' and not (mt and mt.__tostring)
end

--- Check if the table is marked
--  @param t Table to check
--  @return true in the case of marked table
local function ismark(t)
  return getmetatable(t) == _marker
end

-- Main table
local t2t = {
  _sym = unicode,  -- table with symbols
  _nl  = '\n',     -- new line
}

--- Use Unicode symbols to print the tree
t2t.setUnicode = function () t2t._sym = unicode end

--- Use ASCII symbols to print the tree
t2t.setAscii = function () t2t._sym = ascii end

--- Name format for lists
--  @param t List item
--  @return String with name
t2t._listName = function (t)
  return istable(t) and '{}' or tostring(t)
end

--- Generate iterator for a list 
--  @param t List item
--  @return Iterator over child elements
t2t._listIter = function (t)
  local i = 0
  if istable(t) then 
    return function ()
      i = i + 1
      return t[i]
    end
  else
    return function () return nil end
  end
end

--- Name format for map
--  @param t Map item
--  @return String with name
t2t._mapName = function (t)
  if ismark(t) then
    local key = tostring(t[1])
    return istable(t[2]) and key..'={}' or key..'='..tostring(t[2])
  else
    return '{}'
  end
end

--- Generate iterator for a map
--  @param t Map item
--  @return Iterator over child elements
t2t._mapIter = function (t)
  local k, v
  if ismark(t) then 
    t = istable(t[2]) and t[2] or {}
  end
  return function ()
    k, v = next(t, k)
    return k and setmetatable({k,v}, _marker)
  end
end

--- Print subtree 
--  @param this_v Current node
--  @param prev_str Previous string in current line
--  @param new_str String in current position 
--  @param out Output stream
--  @return Table with the collected strings
t2t._child = function (this_v, prev_str, new_str, out)
  local name, iterator = t2t.f_name(this_v), t2t.f_iterator(this_v)
  prev_str = prev_str .. name                -- current string
  local this_ch = iterator()                 -- first children
  if this_ch then new_str = new_str .. string.rep(' ', name:len()) end
  local first, sym = true, t2t._sym
  while this_ch do
    local next_ch = iterator()              -- next children
    if next_ch then
      t2t._child(this_ch,
                  first and (prev_str .. sym.d) or (new_str .. sym.r),
                  new_str .. sym.v, out)
    else
      t2t._child(this_ch,
                  first and (prev_str .. sym.h) or (new_str .. sym.u),
                  new_str .. sym.e, out)
   end
   this_ch = next_ch
   first = false
  end
  if first then out:write(prev_str, t2t._nl) end  -- save if no sucessors
end

--- General form of the print function
--  @param T Table to print
--  @param f_node_name Node name generator
--  @param f_node_iterator Generator of the child iteration function
--  @param filename [optional] Name for saving the result
t2t.print = function (T, f_node_name, f_node_iterator, filename)
  assert(f_node_name, "Expected funcion for the leaf name definition")
  assert(f_node_iterator, "Expected generator for the leaf iterators")
  t2t.f_name = f_node_name
  t2t.f_iterator = f_node_iterator
  -- create
  if filename then 
    local f = io.open(filename, 'w')
    t2t._child(T, "", "", f)
    f:close()
  else
    t2t._child(T, "", "", io.output())
  end
end

--- Simplified print call for lists (keys are integers)
--  @param T Table to print
--  @param filename [optional] Name for saving the result
t2t.printList = function (T, filename)
  t2t.print(T, t2t._listName, t2t._listIter, filename)
end

--- Simplified print call for the general tables
--  @param T Table to print
--  @param filename [optional] Name for saving the result
t2t.printMap = function (T, filename)
  t2t.print(T, t2t._mapName, t2t._mapIter, filename)
end

return t2t

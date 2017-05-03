
--[[ Tree-like graph representation in style of Linux 'pstree'
 
 Usage:
 
 For using this module you should call function 
 
 tree.print(T, f_leaf_name, f_leaf_iterator [,filename])
 
 where T - tree for printing,
       f_leaf_name - function f(t) that defines name for current leaf
       f_leaf_iterator - generator f(t) that returns function for iterations throw childs of current leaf
       filename - optional argument, if it is defined, result will be saved into file
]]

-- elements of tree branches
local br = {v='│',h='─',ur='└',r='├',d='┬'}

local tree = {}
-- string accumulator
tree.acc = {}
-- helpful strings
tree.hor_v = ' '  .. br.v  .. ' '
tree.hor_r = ' '  .. br.r  .. br.h
tree.hor_u = ' '  .. br.ur .. br.h
tree.hor_d = br.h .. br.d  .. br.h
tree.hor_l = br.h .. br.h  .. br.h

-- tree developer
function tree.child(this_v, prev_str, new_str)
   local name = tree.f_name(this_v)             -- node
   prev_str = prev_str .. name                  -- current string
   local iterator = tree.f_iterator(this_v)
   local this_ch = iterator()                   -- first children
   if this_ch then new_str = new_str .. string.rep(' ', name:len()) end
   local first = true
   while this_ch do
      local next_ch = iterator()                -- next children
      if next_ch then
         tree.child(this_ch,  
		    first and (prev_str .. tree.hor_d) or (new_str .. tree.hor_r),
                    new_str .. tree.hor_v)
      else
         tree.child(this_ch, 
		    first and (prev_str .. tree.hor_l) or (new_str .. tree.hor_u),
                    new_str .. '   ')
      end
      this_ch = next_ch
      first = false
   end         
   if first then tree.acc[#tree.acc+1] = prev_str end -- save if no more sucessors
end

-- show tree
function tree.print(T, f_leaf_name, f_leaf_iterator, filename)
   assert(f_leaf_name, "Expected funcion for leaf name definition")
   assert(f_leaf_iterator, "Expected generator for creating leaf iterators")
   tree.f_name = f_leaf_name
   tree.f_iterator = f_leaf_iterator
   -- create
   tree.child(T, "", "")
   local graph = table.concat(tree.acc, '\n')
   -- save
   if filename then
      local f = io.open(filename, 'w')
      f:write(graph)
      f:close()
   else
      print(graph)
   end
end

-- example
--[[
local test = {  -- tree graph
   {
      {{name='bb'},{name='lk'}, name='sd'},
      {{name='te'},{name='on'}, name='gb'},
      {name='fe'},
      name='we'
   },
   name='tr'
}

--local test2 = {{name='de'},name='ff'}

tree.print(-- graph 
           test, 
           -- get name
           function (t) return t.name end,
	   -- use iterator
	   function (t) 
	      local i = 0
	      return function() i=i+1; return t[i] end
	   end,
	   -- save to file (optional)
           'test.txt'
          )
]]

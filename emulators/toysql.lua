--[[		toysql.lua 

Simple Lua imitation of database with SQL requests

Limitations:
  * one table
  * no optimisations
  * inserted values must have right order
  * etc.

~~~~~~~ Example ~~~~~~~~

DB = require 'toysql'
-- create table
tbl = DB:CREATE_TABLE {'id','name','age','salary'}
DB:INSERT_INTO(tbl):VALUES(1,'Ann',20,300)
DB:INSERT_INTO(tbl):VALUES(2,'Tom',42,500)
DB:INSERT_INTO(tbl):VALUES(3,'Jack',33,400)
DB:INSERT_INTO(tbl):VALUES(4,'John',54,600)
DB:INSERT_INTO(tbl):VALUES(5,'Jane',25,400)
DB:DESCRIBE(tbl)
-- simple requests
tmp = DB:SELECT('*'):FROM(tbl):ORDER_BY('salary')
print(tmp)
print( DB:SELECT('name','age'):FROM(tbl):ORDER_BY('age'):DESC():LIMIT(2,4) )
-- conditions
print( DB:SELECT('name'):FROM(tbl):WHERE(tbl.salary:BETWEEN(250,550)) )
print( DB:SELECT('name','age'):FROM(tbl):WHERE(tbl.id:EQ(2)) )
print( DB:SELECT('id','name'):FROM(tbl):WHERE(tbl.salary:LE(300):OR(tbl.age:GT(50))) )
print( DB:SELECT('name'):FROM(tbl):WHERE(tbl.salary:GT( DB:SELECT('salary'):FROM(tbl):AVG() )) )
-- modification
DB:UPDATE(tbl):SET('name','Bob','age',37):WHERE(tbl.id:EQ(3))
DB:ALTER_TABLE(tbl):CHANGE('id','index')
DB:DELETE_FROM(tbl):WHERE(tbl.id:EQ(2))
print(tbl)

2018, Stanislav Mikhel ]]

-- Auxilary class for sintax simplification
local columns = {}
columns.__index = columns

-- Base class
local toysql = {}
toysql.__index = toysql

-- Constructor
toysql.CREATE_TABLE = function (self,t)
   local o = {}
   for k,v in ipairs(t) do o[v] = setmetatable({pose = k, src = o},columns) end
   o._cols = t
   return setmetatable(o,self)
end

-- Wrapper
toysql.INSERT_INTO = function (_,t) return t end

-- Insert new data row
toysql.VALUES = function (t,...)
   local val = {...}
   -- simple check of type equality
   if #t > 0 then   
      for i,v in ipairs(val) do assert(type(v) ~= t[#t][i], 'Wrong types!') end
   end
   t[#t+1] = val
end

-- Wrapper
toysql.SELECT = function (self,...)
   return setmetatable({...},self)
end

-- Create "billet" for the goal table
toysql.FROM = function (names,t)
   -- select columns
   if #names == 1 and names[1] == '*' then names = t._cols end -- show all
   local cols = {}
   for _,nm in ipairs(names) do 
      if not t[nm] then error(nm..' not in table!') end        -- name correctness
      cols[#cols+1] = nm
   end
   -- prepare result table
   local new = toysql:CREATE_TABLE(cols)
   for i,v in ipairs(t) do
      local row = {}
      for _,nm in ipairs(names) do
         row[#row+1] = v[t[nm].pose]
      end
      new[#new+1] = row
   end
   return new
end

-- Sort
toysql.ORDER_BY = function (t,key)
   local pos = t[key].pose
   table.sort(t, function (a,b) return a[pos] < b[pos] end)
   return t
end

-- Revert order
toysql.DESC = function (t)
   local res = toysql:CREATE_TABLE(t._cols)
   for i = #t,1,-1 do res[#res+1] = t[i] end
   return res
end

-- Index range
toysql.LIMIT = function (t,a,b)
   if not b then a,b = 1,a end                                  -- correct indeces if need
   local res = toysql:CREATE_TABLE(t._cols)
   for i = a,b do res[#res+1] = t[i] end
   return res
end

-- Table processing based on locigal results
toysql.WHERE = function (t,logic)
   if t._set then
   -- update
      for i = 1,#t do
         if logic[i] then 
	    for j = 1, #t._set, 2 do
	       local pos = t[t._set[j]].pose
	       t[i][pos] = t._set[j+1]
	    end--for
	 end--if
      end--for
      t._set = nil
   elseif t._delete then
   -- delete
      for i = #logic,1,-1 do
         if logic[i] then table.remove(t,i) end
      end
      t._delete = nil
   else
   -- select rows
      local res = toysql:CREATE_TABLE(t._cols)
      for i = 1,#t do
         if logic[i] then res[#res+1] = t[i] end
      end
      return res
   end
end

-- Wrapper
toysql.UPDATE = function (_,t) return t end

-- List of pairs column/value to update
toysql.SET = function (t,...)
   t._set = {...}
   return t
end

-- Wrapper
toysql.DELETE_FROM = function (_,t) 
   t._delete = true
   return t 
end

-- Wrapper
toysql.ALTER_TABLE = function (_,t) return t end

-- Rename column
toysql.CHANGE = function (t,old,new)
   local pos = t[old].pose
   t[new] = t[old]; t[old] = nil
   t._cols[pos] = new
end

-- Print table summary
toysql.DESCRIBE = function (_,t)
   print('Columns = (' .. table.concat(t._cols,',')..')')
   print('Rows = '..tonumber(#t))
end

-- Number of rows
toysql.COUNT = function (self,t)
   t = t or self                       -- for diferent function calls
   return #t
end

-- Sum of values in first column
toysql.SUM = function (self,t)
   t = t or self
   local s = 0
   for i = 1,#t do s = s+t[i][1] end   -- only first column
   return s
end

-- Average value of the first column
toysql.AVG = function (self,t)
   t = t or self
   return toysql.SUM(t) / #t
end

-- Minimum value in the first column
toysql.MIN = function (self,t)
   t = t or self
   local m = math.huge
   for _,v in ipairs(t) do
      if v < m then m = v end
   end
   return m
end

-- Maximum value in the first column
toysql.MAX = function (self,t)
   t = t or self
   local m = -math.huge
   for _,v in ipairs(t) do
      if v > m then m = v end
   end
   return m
end

-- String representation of the table
toysql.__tostring = function (t)
   local delim = '\t| '
   local res = {table.concat(t._cols,delim):upper()}
   for i,v in ipairs(t) do
      res[#res+1] = table.concat(v,delim)
   end
   return table.concat(res,'\n')
end

--	 Columns methods
-- Make list of true/false values
columns._trueList = function (t,col,fn)
   local res = {AND=columns.AND, OR=columns.OR}
   for i,v in ipairs(t) do res[i] = fn(v[col]) end
   return res
end

-- a == b
columns.EQ = function (t,val)
   return columns._trueList(t.src, t.pose, function (x) return x == val end)
end

-- a ~= b
columns.NE = function (t,val)
   return columns._trueList(t.src, t.pose, function (x) return x ~= val end)
end

-- a < b
columns.LT = function (t,val)
   return columns._trueList(t.src, t.pose, function (x) return x < val end)
end

-- a <= b
columns.LE = function (t,val)
   return columns._trueList(t.src, t.pose, function (x) return x <= val end)
end

-- a > b
columns.GT = function (t,val)
   return columns._trueList(t.src, t.pose, function (x) return x > val end)
end

-- a >= b
columns.GE = function (t,val)
   return columns._trueList(t.src, t.pose, function (x) return x >= val end)
end

-- x >= a and x <= b
columns.BETWEEN = function (t,v1,v2)
   return columns._trueList(t.src, t.pose, function (x) return x >= v1 and x <= v2 end)
end

-- x in (a,b,...)
columns.IN = function (t,...)
   local val = {...}
   local test = function (x) 
            for i = 1,#val do
	       if x == val[i] then return true end
	    end   
	    return false
         end
   return columns._trueList(t.src, t.pose, test)
end

-- Check if value contains given template
columns.LIKE = function (t,templ)
   return columns._trueList(t.src, t.pose, function (x) return string.find(x,templ) ~= nil end)
end

-- And method for two logical lists
columns.AND = function (a,b)
   for i = 1,#a do a[i] = (a[i] and b[i]) end
   return a
end

-- Or method for two logical lists
columns.OR = function (a,b)
   for i = 1,#a do a[i] = (a[i] or b[i]) end
   return a
end

return toysql

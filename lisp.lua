#!/usr/local/bin/lua

--[[		lisp.lua

Simple Lisp interpretator in Lua. Interacts with user in 'read-and-evaluate' form. Inspired by www.norvig.com/lispy.html

2017, Stanislav Mikhel ]]

local lisp = {}

-- Prepare table for environment
lisp.Env = function (pars, args, outer)
   local dict = {outer = outer}
   for i = 1, #pars do dict[pars[i]] = args[i] end
   -- check existance of symbol
   dict._find_ = function (self, v) return self[v] and self or self.outer:_find_(v) end
   return dict
end

-- Standard environment
lisp.standard = lisp.Env({}, {}, {_find_=function() return nil end}) -- outer table doesn't exists
-- some of base functions
lisp.standard['+'] = function (a,b) return a+b end
lisp.standard['-'] = function (a,b) return a-b end
lisp.standard['*'] = function (a,b) return a*b end
lisp.standard['/'] = function (a,b) return a/b end
lisp.standard['#t'] = true
lisp.standard['#f'] = false
lisp.standard['append'] = function (a,b) return table.move(b, 1, #b, #a+1, table.move(a, 1, #a, 1, {})) end
lisp.standard['apply'] = function (a,b) return a(table.unpack(b)) end
lisp.standard['begin'] = function (...) local a = {...}; return a[#a] end
lisp.standard['car'] = function (lst) return lst[1] end
lisp.standard['cdr'] = function (lst) return table.move(lst, 2, #lst, 1, {}) end
lisp.standard['cons'] = function (a, lst) return table.move(lst, 1, #lst, 2, {a}) end
lisp.standard['eq?'] = function (a,b) return a == b end
lisp.standard['length'] = function (a) return #a end
lisp.standard['list'] = function (...) return {...} end
lisp.standard['list?'] = function (a) return type(a) == 'table' end
lisp.standard['null?'] = function (a) return a == nil end
lisp.standard['number?'] = function (a) return tonumber(a) ~= nil end
lisp.standard['map'] = function (fn, a) local v = {}; for i = 1,#a do v[i] = fn(a[i]) end; return v end

-- Expression evaluation
lisp.eval = function (x, env)
   env = env or lisp.standard
   if type(x) ~= 'table' then
      local elt = env:_find_(x)
      if elt then return elt[x] end                 -- is symbol
      if tonumber(x) then return tonumber(x) end    -- is number
      if string.find(x, '".*"') then return x end   -- is string ("" must be used)
      error('Undefined: ' .. tostring(x))
   else
      if x[1] == 'quote' then                      
         return x[2]
      elseif x[1] == 'if' then
         -- test, conseq, alt = x[2], x[3], x[4]
         local exp = lisp.eval(x[2], env) and x[3] or x[4]
         return lisp.eval(exp, env)
      elseif x[1] == 'define' then
         env[x[2]] = lisp.eval(x[3], env)           -- var, exp = x[2], x[3]
      elseif x[1] == 'lambda' then
	 return lisp.Proc(x[2], x[3], env)          -- pars, body = x[2], x[3]
      else
         -- procedure from environment
         local proc = lisp.eval(x[1], env)
         local args = {}
         for i = 2, #x do
	    local v = lisp.eval(x[i], env)
	    if v then table.insert(args, v) end
         end
         return proc(table.unpack(args))
      end
   end
end

-- User defined procedure (lambda)
lisp.Proc = function (pars, body, env)
   local dict = {pars = pars, body = body, env = env}
   -- make callable
   setmetatable(dict, 
   { __call = function (self, ...)
                 return lisp.eval(self.body, lisp.Env(self.pars, {...}, self.env))
              end })
   return dict
end

-- List representation
lisp.tostring = function (lst)
   if type(lst) ~= 'table' then return tostring(lst) end
   local str = {}
   for _, a in ipairs(lst) do
      table.insert(str, lisp.tostring(a))
   end
   return string.format("(%s)", table.concat(str, " "))
end

-- Create list (parsing tree) from tokens
lisp.tree = function (tok)
   local t = table.remove(tok, 1)
   if t == '\'' then return {'quote', lisp.tree(tok)} end   -- use ' for quote
   if t == '(' then                                         -- new list
      local tbl = {}
      while tok[1] ~= ')' do
         table.insert(tbl, lisp.tree(tok))
      end
      table.remove(tok, 1)                                  -- remove ')'
      return tbl
   else
      return t ~= ')' and t or error("Wrong syntax!")
   end
end

-- Get tokens
lisp.parse = function (s)
   s = s:gsub(';+.-\n', '\n')                                     -- remove comments
   s = s:gsub('[()\']', {['(']=' ( ',[')']=' ) ', ['\'']=' \' '}) -- white space as delimeter
   local tok = {}
   for w in s:gmatch('%S+') do table.insert(tok, w) end           -- parse
   return lisp.tree(tok)
end

-- Read string and check ballance of brackets
lisp.read = function (invite)
   local n, str = 0, ""
   repeat
      io.write(n == 0 and invite or '.. '); io.flush()
      local new = io.read()
      for c in new:gmatch('[()]') do n = n + (c == '(' and 1 or -1) end
      str = str .. new .. (n > 0 and '\n' or '')
   until n <= 0
   return str
end

-- Interpretator
lisp.repl = function ()
   print("Print 'q' to quit")
   while true do
      local s = string.lower(lisp.read("? "))
      if s == 'q' then break end
      local res = (#s > 0) and lisp.eval(lisp.parse(s)) or nil
      if res then print(lisp.tostring(res)) end
   end
   print("Bye!")
end

-- Simplify interpretator call
setmetatable(lisp, {__call = function () return lisp.repl() end})

-- Start LISP!
lisp()

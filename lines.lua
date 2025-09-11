#!/usr/bin/lua

--[[		lines.lua

Count line numbers in code. Include all subdirectories and languages that are predefined. Work in Linux by default.

Usage:
  * lua lines.lua directory - analize given directory
  * lua lines.lua           - analize current directory

2017, Stanislav Mikhel ]]

-- list of languages
local types =
{
   {name='Python', code={'py','pyw'}},
   {name='Lua',  code={'lua'}},
   {name='Java', code={'java'}},
   {name='C#',   code={'cs'}},
   {name='C++',  code={'cpp','hpp'}},
   {name='C',    code={'c','h'}},
   {name='JS',   code={'js'}},
   {name='Bash', code={'sh'}},
   {name='XML',  code={'xml'}},
   {name='HTML', code={'html','htm'}},
   {name='make', code={'/makefile', '/Makefile'}},
}

-- constants
local FILE, DIR = 'file', 'dir'

-- detect the type of item (Linux)
local function _filetype(str)
   local last = string.match(str, '(.)$')
   if string.find(last, '[%*=>@|]') then
      return nil
   else
      return {type=(last=='/') and DIR or FILE, name=str}
   end
end

-- get list of items in current directory
local function _listdir(path)
   local lst = {}
   local f = io.popen('ls -F ' .. path)
   for line in f:lines() do
      local tp = _filetype(tostring(line))
      if tp then lst[#lst+1] = tp end
   end
   return lst
end

-- collect
local ln = { defined = {}, suffix = {} }

-- get number of lines in file (except empty)
local function _filelines(fname)
   local s = string.match(fname, '.*%.(.-)$') or ''
   s = string.lower(s)
   -- file suffix is not in list of types
   if not ln.defined[s] then return end

   local n = 0
   for line in io.lines(fname) do
      if line:len() > 0 then n=n+1 end
   end
   ln.suffix[s] = (ln.suffix[s] or 0) + n
end

-- recursive pass
local function _dirlines(path)
   local lst = _listdir(path)
   for i = 1, #lst do
      if lst[i].type == FILE then
         _filelines(path .. lst[i].name)
      else
         _dirlines(path .. lst[i].name)
      end
   end
end

-- checking
local function main()
   local path = arg[1] or './'
   -- prepare suffix list
   for i = 1, #types do
      local code = types[i].code
      for _, c in ipairs(code) do ln.defined[c] = types[i].name end
   end
   -- analize directory
   _dirlines(path)
   -- summ of lines
   local sum, res = 0.0, {}
   for suf, k in pairs(ln.suffix) do
      local lang = ln.defined[suf]
      res[lang] = (res[lang] or 0) + k
      sum = sum + k
   end
   -- results
   print '---- Results ----'
   for name, val in pairs(res) do
      print( ("%s\t%d\t%.2f%%"):format(name, val, (val/sum)*100) )
   end
end

-- start checking
main()

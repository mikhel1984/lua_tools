#!/usr/local/bin/lua

-- Extract comments from file (or list of files in current directory)

-- Usage:
--   lua comments.lua <filename> - for concrete file
--   lua comments.lua            - for all files

local LANG      = "cpp"   -- file type (from table 'types')
local NOLISENCE = true    -- don't show license if it is founded

-- comment style for different file types
local types = {
   cpp={single='//', multi={'/%*','%*/'}},
   python={single='#', multi={'"""','"""'}},
   lua={single='%-%-', multi={'%-%-%[%[','%]%]%-%-'}},
}

local com = {}

com.accumulator = {}
com.multiline = false
com.mfirst = nil
com.mlast = nil
com.sfirst = nil

-- print comments for given file
function com.printfile(name)
   local i = 0
   for line in io.lines(name) do
      i = i+1
      com.dispetcher(line, i)
   end
end

-- add string to accumulator, insert number
function com.add(i, str)
   com.accumulator[#com.accumulator+1] = string.format('%d %s', i, str)
end

-- decide if it is a comment or not
function com.dispetcher(str, i)
   local tmp
   if com.multiline then
      -- fill multiline comment
      tmp = string.match(str, com.mlast)
      if tmp then
         -- if comment was closed
         com.add(i, tmp)
	 com.multiline = false
      else
	 -- not still closed 
         com.add(i, str)
      end
   else
      -- check single line comment
      tmp = string.match(str, com.sfirst)
      if tmp then
         com.add(i, tmp)  
      -- check multiline comment
      else
         tmp = string.match(str, com.mfirst)
	 if tmp then 
	    local tmp2 = string.match(tmp, com.mlast)
	    -- mark if not end
	    if tmp2 then tmp = tmp2 else com.multiline = true end
	    com.add(i, tmp)
	 end
      end
      -- print if end of comment
      if not tmp and #com.accumulator > 0 then
         com.accprint()
      end
   end
end

-- show content of accumulator
function com.accprint()
   local str = table.concat(com.accumulator, '\n')
   if not (NOLISENCE and str:find('License')) then 
      print(str, '\n')   
   end
   com.accumulator = {}
end

-- create list of files in current directory (Linux)
function com.listdir()
   local lst = {}
   local f = io.popen('ls -F ')
   for line in f:lines() do 
      if string.find(line, "%w$") then
         lst[#lst+1] = line 
      end
   end
   return lst
end

-- main
function com.print()
   -- find files for analize
   local list = arg[1] and { arg[1] } or com.listdir()
   -- create templates
   com.sfirst = types[LANG].single and ('^%s*' .. types[LANG].single .. '(.*)') or nil
   com.mfirst = types[LANG].multi  and ('^%s*' .. types[LANG].multi[1] .. '(.*)') or nil
   com.mlast  = types[LANG].multi  and ('(.*)' .. types[LANG].multi[2]) or nil
   -- analize list of files
   for i = 1, #list do
      --print('\nFile: ', list[i])
      print(string.format("\n               =======<  %s  >=======\n", list[i]))
      com.printfile(list[i])
   end
end

-- run
com.print()

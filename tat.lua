#!/usr/local/bin/lua

--[[		tat.lua

Convert text to Tatar version by replacing combinations 
such like 'а*' or 'А*' to ә and Ә respectively. 

Usage:
   lua tat.lua file_to_convert

2025, Stanislav Mikhel ]]

-- check arguments
if not arg[1] then
   print(string.format('Usage: lua %s file_to_convert', arg[0]))
   os.exit()
end
-- rules
convert = {
  ['А']='Ә', ['Ж']='Җ', ['Н']='Ң', ['О']='Ө', ['У']='Ү', ['Х']='Һ', 
  ['а']='ә', ['ж']='җ', ['н']='ң', ['о']='ө', ['у']='ү', ['х']='һ',
}
-- return the same when not found
setmetatable(convert, {__index=function(a,b) return b..'*' end})
-- prepare new file
tmpname = arg[1] .. '(1)'
res = io.open(tmpname, 'w')
-- convert and write
for line in io.lines(arg[1]) do
   res:write(string.gsub(line, "("..utf8.charpattern..")%*", convert), '\n')
end
-- save
res:flush(); res:close()
-- change
os.remove(arg[1])
os.rename(tmpname, arg[1])
print("Done!")


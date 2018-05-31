#!/usr/local/bin/lua

--[[		eo.lua

Convert text to Esperanto version by replacing combinations 
such like 'cx' or 'Cx' to ĉ and Ĉ respectively. 

Usage:
   lua eo.lua file_to_convert

2017, Stanislav Mikhel ]]

-- check arguments
if not arg[1] then
   print(string.format('Usage: lua %s file_to_convert', arg[0]))
   os.exit()
end
-- rules
convert = {C='Ĉ',G='Ĝ',H='Ĥ',J='Ĵ',S='Ŝ',U='Ǔ',
           c='ĉ',g='ĝ',h='ĥ',j='ĵ',s='ŝ',u='ǔ'}
setmetatable(convert, {__index=function(a,b) return b..'x' end})
-- prepare new file
tmpname = arg[1] .. '(1)'
res = io.open(tmpname, 'w')
-- convert and write
for line in io.lines(arg[1]) do
   res:write(string.gsub(line, '(.)x', convert), '\n')
end
-- save
res:flush(); res:close()
-- change
os.remove(arg[1])
os.rename(tmpname, arg[1])
print("Done!")


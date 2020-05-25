#!/usr/local/bin/lua
--[[    backup.lua

Save and restore changes in text files.
See "usage" for details.

2020, Stanislav Mikhel ]]

local usage = [[
USAGE: ./backup.lua file cmd [option]

  Commands:
    add [msg] - save changes in file
    rev [n]   - create n-th revision of the file
    diff [n]  - comapre file with n-th revision
    log       - show all commits
]]

local EXT = ".bkp"   -- output extention

require "diff"       -- file comparison

local backup = {}
-- show commits
backup.log = function (fname)
  local v = pcall(function() 
    for line in io.lines(fname..EXT) do
      if string.find(line, "^BKP NEW ") then
        print(string.sub(line, 9))
      end
    end
  end)
  if not v then print("Empty") end 
end
-- make single-linked list
backup._addString = function (s, parent)
  parent.child = {s, child=parent.child}
  return parent.child
end
-- move forward along the list
backup._goTo = function (node, iCur, iGoal)
  for i = iCur+1, iGoal do node = node.child end
  return node, iGoal
end
-- list to table
backup._tbl = function (ptr)
  local t = {}
  while ptr do
    t[#t+1] = ptr[1]
    ptr = ptr.child
  end
  return t
end
-- prepare file version based on bkp file
backup._make = function (fname, last) 
  local f = io.open(fname..EXT, 'r') 
  if f == nil then return {}, 0 end
  -- continue if the file found
  local begin = {}
  local curr, index, id, del = nil, 0, 0, true
  for line in f:lines() do
    if #line > 8 and string.find(line, "^BKP ") then 
      -- execute command
      local cmd, v1, v2 = string.match(line, "^BKP (%u%u%u) (%d+) : (.*)")
      v1 = tonumber(v1)
      if cmd == "NEW" then                            -- commit
        if v1-1 == last then break 
        else 
          curr, index, id, del = begin, 0, v1, true   -- reset all
        end
      elseif cmd == "ADD" then                        -- insert lines
        if del then
          curr, index, del = begin, 0, false          -- reset, change flag
        end
        curr, index = backup._goTo(curr, index, v1-1)
      elseif cmd == "REM" then                        -- remove lines
        curr, index = backup._goTo(curr, index, v1-1)  
        local curr2, index2 = backup._goTo(curr, index, v1+tonumber(v2))
        curr.child, index = curr2, index2 - 1         -- update indexation
      end
    else
      -- insert line
      curr = backup._addString(line, curr)             
      index = index + 1
    end
  end
  f:close()
  return backup._tbl(begin.child), id
end
-- "commit"
backup.add = function (fname, msg)
  local saved, id = backup._make(fname) 
  local new = diff.read(fname)
  local common = diff.lcs(saved, new) 
  if #saved == #new and #new == #common-1 then
    return print("Nothing to add")
  end
  -- save commit
  local f = io.open(fname..EXT, "a")
  f:write(string.format("BKP NEW %d : %s\n", id+1, msg or ''))
  -- remove old lines
  if #saved > #common-1 then
    for n = 1, #common do
      local n1, n2 = common[n-1][1]+1, common[n][1]
      if n2 > n1 then
        f:write(string.format("BKP REM %d : %d\n", n1, n2-n1))
      end
    end
  end
  -- add new lines
  if #new > #common-1 then
    for n = 1, #common do
      local n1, n2 = common[n-1][2]+1, common[n][2]
      if n2 > n1 then
        f:write(string.format("BKP ADD %d : %d\n", n1, n2-n1))
        for i = n1, n2-1 do f:write(new[i],'\n') end
      end
    end
  end
  print(string.format("Save [%d] %s", id+1, msg or ''))
end
-- restore the desired file version
backup.rev = function (fname, ver)
  ver = ver and tonumber(ver)    -- string to number
  local saved, id = backup._make(fname, ver) 
  if ver and id ~= ver then return print("No revision", ver) end
  -- save result
  io.open(fname, "w"):write(table.concat(saved, '\n'))
end
-- difference between the file and some revision
backup.diff = function (fname, ver)
  ver = ver and tonumber(ver)    -- string to number
  local saved, id = backup._make(fname, ver) 
  if ver and id ~= ver then return print("No revision", ver) end
  -- compare
  diff.print(saved, diff.read(fname))
end

setmetatable(backup, {__index=function() 
  print(usage) 
  return function() end
end})

--============== Call ===================

backup[arg[2]](arg[1], arg[3])


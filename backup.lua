#!/usr/local/bin/lua
--[[    backup.lua

Save and restore changes in text files.
See "usage" for details.

2020, Stanislav Mikhel ]]

local usage = [[
USAGE: ./backup.lua file cmd [option] [branch]

  Commands:
    add  [msg] [br] - save changes in file
    rev  [n]   [br] - create n-th revision of the file
    diff [n]   [br] - comapre file with n-th revision
    log        [br] - show all commits
    vs   file2      - compare two files
]]

local EXT = ".bkp"   -- output extention

-- file comparison
local diff = {}
-- Convert text file into the table of strings
diff.read = function (fname)
  local t = {}
  for line in io.lines(fname) do t[#t+1] = line end
  return t
end
-- Find longest common "substrings"
diff.lcs = function (a, b)
  local an, bn = #a, #b
  -- skip end 
  while an > 1 and bn > 1 and a[an] == b[bn] do
    an, bn = an-1, bn-1
  end
  -- skip begin 
  local ab = 1
  while ab < an and a[ab] == b[ab] do
    ab = ab + 1
  end
  local S, ab1 = {}, ab-1
  S[ab1] = setmetatable({}, {__index=function() return ab1 end}) 
  -- fill table
  for i = ab, an do
    S[i] = {[ab1]=ab1}
    local Si,Si1, ai = S[i],S[i-1],a[i]
    for j = ab, bn do
      Si[j] = (ai==b[j]) and (Si1[j-1]+1) 
                          or math.max(Si[j-1], Si1[j]) 
    end
  end
  local Ncom = S[an][bn] -- total number of common strings
  local N = Ncom + #a - an 
  -- prepare table
  local common = {}
  for i = 1,N do 
    common[i] = (i < ab) and {i,i} or 0
  end 
  -- collect
  while Ncom >= ab do
    if S[an][bn] == S[an-1][bn] then 
      an = an - 1
    elseif S[an][bn] == S[an][bn-1] then 
      bn = bn - 1
    else
      --assert (a[an] == b[bn])
      common[Ncom] = {an, bn} 
      an, bn, Ncom = an-1, bn-1, Ncom-1
    end
  end
  for i = Ncom+1, N do
    an, bn = an+1, bn+1
    common[i] = {an,bn}
  end
  -- for further processing
  common[0] = {0, 0}
  common[#common+1] = {#a+1, #b+1}
  return common 
end
-- show difference
diff.print = function (a, b)
  local common = diff.lcs(a, b)
  local tbl, sign = {a, b}, {"-- ", "++ "}
  for n = 1, #common do
    for k = 1,2 do
      local n1, n2 = common[n-1][k]+1, common[n][k]-1
      if n2 >= n1 then
        io.write("@@ ", n1, "..", n2, "\n")
        for i = n1, n2 do io.write(sign[k], tbl[k][i], "\n") end
      end
    end
  end
end

-- make single-linked list
local function addString (s, parent)
  parent.child = {s, child=parent.child}
  return parent.child
end

-- move forward along the list
local function goTo (node, iCur, iGoal)
  for i = iCur+1, iGoal do node = node.child end
  return node, iGoal
end

-- list to table
local function toTbl (ptr)
  local t = {}
  while ptr do
    t[#t+1] = ptr[1]
    ptr = ptr.child
  end
  return t
end
-- prepare backup file name
local function bkpname(fname,br)
  return fname..(br and ('.'..br) or '')..EXT
end

-- parse command line arguments
local argparse = {}
-- add msg branch | add msg | add
argparse.add = function ()
  return bkpname(arg[1],arg[4]), arg[3]
end
-- log branch | log
argparse.log = function ()
  return bkpname(arg[1],arg[3]), nil
end
-- rev n branch | rev n | rev branch | rev
argparse.rev = function ()
  if arg[4] then 
    return bkpname(arg[1],arg[4]), tonumber(arg[3])
  end
  local n = tonumber(arg[3]) 
  if n then
    return bkpname(arg[1],nil), n
  else
    return bkpname(arg[1],arg[3]), nil
  end
end
-- diff n branch | diff n | diff branch | diff
argparse.diff = argparse.rev
-- return backup name and parameter
argparse.get = function ()
  return argparse[arg[2]]()
end

local backup = {}
-- show commits
backup.log = function ()
  local fname = argparse.get()
  local v = pcall(function() 
    for line in io.lines(fname) do
      if string.find(line, "^BKP NEW ") then
        print(string.sub(line, 9))
      end
    end
  end)
  if not v then print("Empty") end 
end
-- prepare file version based on bkp file
backup._make = function (fname, last) 
  local f = io.open(fname, 'r') 
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
        curr, index = goTo(curr, index, v1-1)
      elseif cmd == "REM" then                        -- remove lines
        curr, index = goTo(curr, index, v1-1)  
        local curr2, index2 = goTo(curr, index, v1+tonumber(v2))
        curr.child, index = curr2, index2 - 1         -- update indexation
      end
    else
      -- insert line
      curr = addString(line, curr)             
      index = index + 1
    end
  end
  f:close()
  return toTbl(begin.child), id
end
-- "commit"
backup.add = function ()
  local fname, msg = argparse.get()
  local saved, id = backup._make(fname) 
  local new = diff.read(arg[1])
  local common = diff.lcs(saved, new) 
  if #saved == #new and #new == #common-1 then
    return print("Nothing to add")
  end
  -- save commit
  local f = io.open(fname, "a")
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
backup.rev = function ()
  local fname, ver = argparse.get()
  local saved, id = backup._make(fname, ver) 
  if ver and id ~= ver then return print("No revision", ver) end
  -- save result
  io.open(arg[1], "w"):write(table.concat(saved, '\n'))
end
-- difference between the file and some revision
backup.diff = function ()
  local fname, ver = argparse.get()
  local saved, id = backup._make(fname, ver) 
  if ver and id ~= ver then return print("No revision", ver) end
  -- compare
  diff.print(saved, diff.read(arg[1]))
end
-- comare two files 
backup.vs = function ()
  local fname1, fname2 = arg[1], arg[3]
  if not fname2 then return backup.wtf('?!') end
  diff.print(diff.read(fname1), diff.read(fname2))
end

setmetatable(backup, {__index=function() 
  print(usage) 
  return function() end
end})


--============== Call ===================

backup[arg[2]]()


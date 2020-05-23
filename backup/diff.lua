#!/usr/local/bin/lua
--[[    diff.lua

Looking for common (and differnt) strings in two files. Inspired by 
http://rosettacode.org/wiki/Longest_common_subsequence

2020, Stanislav Mikhel ]]

diff = {}
-- Convert text file into the table of strings
diff.read = function (fname)
  local t = {}
  for line in io.lines(fname) do t[#t+1] = line end
  return t
end
-- Find longest common "substrings"
diff.lcs = function (a, b)
  local S = {}
  local na, nb = #a, #b
  -- prepare initial zeros
  for i = 1,na do S[i] = {[0]=0} end
  S[0] = setmetatable({}, {__index=function() return 0 end}) 
  -- fill table
  for i = 1, na do
    for j = 1, nb do
      S[i][j] = (a[i]==b[j]) and (S[i-1][j-1]+1) 
                             or math.max(S[i][j-1], S[i-1][j]) 
    end
  end
  local N = S[na][nb] -- total number of common strings
  -- prepare table
  local common = {}
  for i = 1,N do common[i] = 0 end 
  -- collect
  while N > 0 do
    if S[na][nb] == S[na-1][nb] then 
      na = na - 1
    elseif S[na][nb] == S[na][nb-1] then 
      nb = nb - 1
    else
      --assert (a[na] == b[nb])
      common[N] = {na, nb} 
      na, nb, N = na-1, nb-1, N-1
    end
  end
  -- for further processing
  common[0] = {0, 0}
  common[#common+1] = {#a+1, #b+1}
  return common 
end
-- show difference
diff.print = function (a, b)
  local common = diff.lcs(a, b)
  local tbl, sign = {a, b}, {"- ", "+ "}
  for n = 1, #common do
    for k = 1,2 do
      local n1, n2 = common[n-1][k]+1, common[n][k]-1
      if n2 >= n1 then
        io.write("/ ", n1, "..", n2, "\n")
        for i = n1, n2 do io.write(sign[k], tbl[k][i], "\n") end
      end
    end
  end
end

--=========== Call ============
if arg[0] == 'diff.lua' then
  if #arg == 2 then 
    diff.print(diff.read(arg[1]), diff.read(arg[2]))
  else
    print("USAGE: ./diff.lua init.txt new.txt")
  end
end

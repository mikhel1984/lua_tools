#!/usr/local/bin/lua

require "loss"

-- create "master"
local master = loss.master() 

-- command line arguments are node names
if #arg > 0 then
  -- collect nodes
  for i = 1, #arg do
    master:add_node(arg[i])
  end
  -- start execution
  master:run() 
else
  print("Usage: lossrun.lua node1.lua node2.lua etc.")
end



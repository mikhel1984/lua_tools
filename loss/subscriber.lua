-- Example of subscriber 

require "loss"

-- define function to call each time when 
-- a new message appear
local function callback(msg)
  -- print received time 
  print(string.format("%02d:%02d:%02d",msg[1],msg[2],msg[3]))
end

-- create node, give name
local node = loss.node('listener')
-- choose topic for subscription
node:subscribe('time',callback)
-- waiting for incoming messages
node:spin()  -- don't use it if you make a circle with loss:ok() method

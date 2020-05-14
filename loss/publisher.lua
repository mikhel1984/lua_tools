-- Example of publisher

require "loss" 

-- create new node, give name
local node = loss.node('talker')
-- set rate to "sleep" between calls
node:rate(1)   -- Hz

-- main circle
while node:ok() do 
  -- do something useful here
  -- for example, publish current time each second
  local t = os.date("*t") 
  -- define topic name, message is a sequance of "atoms"
  node:publish{topic='time',msg={t.hour,t.min,t.sec}}
end

--[[   loss.lua

Lua rOS Simulation

2020, Stanislav Mikhel ]]

--============ Nodes ================

local nodecmd = {}    -- client methods

-- node constructor
nodecmd.new = function (name)
  return setmetatable({name=name, next_call=0, send={}, receive={}}, {__index=nodecmd})
end

-- define rate of calls (in Hz)
nodecmd.rate = function (node, hz) node.period = 1/hz end

-- publish new message
-- data is a table {topic=..; msg=..}
nodecmd.publish = function (node, data)
  table.insert(node.send, data)
end

-- subscibe to topic
nodecmd.subscribe = function (node, name, fn)
  table.insert(node.receive, {topic=name, last_id=-1, call=fn})
end

-- suspend/continue execution
nodecmd.ok = coroutine.yield

-- don't finish execution
nodecmd.spin = function (node)
  while coroutine.yield(node) do end
end

--=============== Master ================

-- run callback functions
local _sendMsgs = function (master, node)
  for _, subs in ipairs(node.receive) do
    local data = master.topics[subs.topic]
    if data and data.id ~= subs.last_id then
      subs.call(data.msg)  -- execute callback
      subs.last_id = data.id
    end
  end
end

-- collect node published messages
local _receiveMsgs = function (master, node)
  while #node.send > 0 do
    local data = table.remove(node.send)
    master.topics[data.topic] = {msg=data.msg, id=math.random(10000)} -- update
  end
end

-- update topics
local _update = function (master, i)
  local obj = master.nodes[i]
  local ok, n = coroutine.resume(obj.thread, true)  -- call node
  if ok and n then
    _receiveMsgs(master, n)
    n.next_call = os.clock() + (n.period or 0)
    i = i+1
  else
    table.remove(master.nodes, i)
  end
  return i
end

local mastercmd = {}  -- server methods

-- master constructor
mastercmd.new = function ()
  return setmetatable({nodes={}, topics={}}, {__index=mastercmd})
end

-- prepare node for execution
mastercmd.add_node = function (master, fname)
  local fn = assert(loadfile(fname))
  local co = assert(coroutine.create(fn))
  local ok, n = coroutine.resume(co)
  if ok and n then table.insert(master.nodes, {thread=co, node=n}) end
end

-- start execution
mastercmd.run = function (master)
  print("Run LossMaster, nodes =", #master.nodes)
  while #master.nodes > 0 do
    local i = 1
    while i <= #master.nodes do
      local n = master.nodes[i].node
      _sendMsgs(master, n)
      i = (os.clock() >= n.next_call) and _update(master, i) or (i + 1)
    end
    -- TODO sleep 1ms
  end
end

--=============== Interface ==============

loss = {
  -- create new node
  node = nodecmd.new,
  -- create new master
  master = mastercmd.new,
  -- parameter exchange
  param = {},
}

return loss

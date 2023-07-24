#!/usr/local/bin/lua

--[[            forth.lua

Simple Forth interpreter.

Usage:
  
  lua forth.lua 
  lua forth.lua code.forth

2023, Stanislav Mikhel ]]

-- Data
local stack = {}   -- parameter stack
local rstack = {}  -- return stack
local dictionary = {}

-- stack operations
local push, pop = table.insert, table.remove

-- Transrom string into list of tokens
local function parse (str)
  str = string.gsub(str, '%s%(%s.-%s%)%s', ' ')  -- remove comments
  local res = {}
  for w in string.gmatch(str, '%S+') do 
    res[#res+1] = tonumber(w) or w 
  end
  return res
end

-- Main evaluation loop
local function eval(cmd, ind, exit)
  if type(cmd) == 'string' then cmd = parse(cmd) end
  while ind <= #cmd do
    local key = cmd[ind]
    if type(key) == 'number' then
      push(stack, key)
      ind = ind + 1
    else
      key = string.lower(key)
      if exit and exit(key) then break end
      local instruction = dictionary[key]
      if type(instruction) == 'function' then
        ind = instruction(cmd, ind) or (ind + 1)
      elseif type(instruction) == 'table' then
        eval(instruction, 1)
        ind = ind + 1
      else
        io.write(key, ' is not ')
        break
      end
    end
  end
  return ind
end

-- Simplify function definition
local function apply2 (op)
  return function ()
    local b = pop(stack)
    local a = pop(stack)
    push(stack, op(a, b))
  end
end

local function apply1 (op)
  return function ()
    local a = pop(stack)
    push(stack, op(a))
  end
end

-- Arithmetic
dictionary['+'] = apply2(function (x, y) return x + y end)
dictionary['-'] = apply2(function (x, y) return x - y end)
dictionary['*'] = apply2(function (x, y) return x * y end)
dictionary['/'] = apply2(function (x, y) return math.floor(x + y) end)
dictionary['min'] = apply2(function (x, y) return (x < y) and x or y end)
dictionary['max'] = apply2(function (x, y) return (x > y) and x or y end)
dictionary['abs'] = apply1(function (x) return (x < 0) and -x or x end)
dictionary['negate'] = apply1(function (x) return -x end)

dictionary['*/'] = function ()
  local c = pop(stack)
  local b = pop(stack)
  local a = pop(stack)
  push(stack, math.floor(a*b/c))
end


-- Logic
dictionary['='] = apply2(function (x, y) return (x == y) and -1 or 0 end)
dictionary['<'] = apply2(function (x, y) return (x < y) and -1 or 0 end)
dictionary['>'] = apply2(function (x, y) return (x > y) and -1 or 0 end)
dictionary['and'] = apply2(function (x, y) return (x ~= 0 and y ~= 0) and -1 or 0 end)
dictionary['or'] = apply2(function (x, y) return (x ~= 0 or y ~= 0) and -1 or 0 end)
dictionary['0='] = apply1(function (x) return (x == 0) and -1 or 0 end)
dictionary['0<'] = apply1(function (x) return (x > 0) and -1 or 0 end)
dictionary['0>'] = apply1(function (x) return (x < 0) and -1 or 0 end)
dictionary['invert'] = apply1(function (x) return (x == 0) and -1 or 0 end)

-- Parameter stack
dictionary['swap'] = function ()
  stack[#stack], stack[#stack-1] = stack[#stack-1], stack[#stack]
end

dictionary['rot'] = function ()
  stack[#stack-2], stack[#stack-1], stack[#stack] = stack[#stack-1], stack[#stack], stack[#stack-2]
end

dictionary['drop'] = function () pop(stack) end
dictionary['dup'] = function () push(stack, stack[#stack]) end
dictionary['over'] = function () push(stack, stack[#stack-1]) end
dictionary['.'] = function () io.write(string.format("%d ", pop(stack))) end

dictionary['?dup'] = function () 
  if stack[#stack] ~= 0 then push(stack, stack[#stack]) end 
end

dictionary['.s'] = function ()
  io.write(string.format('<%d> ', #stack))
  for i = 1, #stack do
    io.write(string.format('%d ', stack[i]))
  end
end

-- Word definition
dictionary[':'] = function (cmd, pos)
  local n = pos+1
  while n <= #cmd and cmd[n] ~= ';' do n = n + 1 end
  dictionary[string.lower(cmd[pos+1])] = table.move(cmd, pos+2, n-1, 1, {})
  return n + 1
end

-- String
dictionary['."'] = function (cmd, pos)
  local n = pos+1
  while n <= #cmd and cmd[n] ~= '"' do n = n + 1 end
  for i = pos+1, n-1 do io.write(cmd[i], ' ') end
  return n + 1
end

-- Conditions
dictionary['if'] = function (cmd, pos)
  local function stop (x) return x=='then' or x=='else' end
  if pop(stack) ~= 0 then 
    -- true
    pos = eval(cmd, pos+1, stop)
    if cmd[pos] == 'else' then
      repeat pos = pos + 1
      until string.lower(cmd[pos]) == 'then'
    end
  else
    -- false
    repeat pos = pos + 1
    until stop(string.lower(cmd[pos]))
    if string.lower(cmd[pos]) == 'else' then
      pos = eval(cmd, pos+1, stop)
    end
  end
  return pos + 1
end

-- loop with indexation
dictionary['do'] = function (cmd, pos)
  local function stop (x) return x == 'loop' or x =='+loop' or x == 'leave' end
  local first = pop(stack)
  local last = pop(stack)
  local pn = pos + 1
  push(rstack, 0)
  local i = first
  while i < last do
    rstack[#rstack] = i
    pn = eval(cmd, pos+1, stop)
    local word = string.lower(cmd[pn])
    if word == '+loop' then
      i = i + pop(stack)
    elseif word == 'loop' then
      i = i + 1
    else  -- leave
      repeat 
        pn = pn + 1
        local w = string.lower(cmd[pn])
      until w == 'loop' or w == '+loop'
      break
    end
  end
  pop(rstack)
  return pn + 1
end

-- loop with conditions
dictionary['begin'] = function (cmd, pos)
  local function stop (x) 
    return x == 'until' or x == 'while' or x == 'repeat' or x == 'leave' end
  local pn = pos+1
  repeat
    pn = eval(cmd, pos+1, stop)
    local word = string.lower(cmd[pn])
    local exitloop = true
    if word == 'until' then
      exitloop = (pop(stack) ~= 0)
    elseif word == 'while' then
      exitloop = (pop(stack) == 0)
      if not exitloop then
        pn = eval(cmd, pn+1, stop)
      else
        -- look for end
        repeat pn = pn + 1
        until stop(string.lower(cmd[pn]))
      end
    elseif word == 'leave' then
      exitloop = true
      repeat 
        pn = pn + 1 
        local w = string.lower(cmd[pn])
      until w == 'until' or w == 'repeat'
    end
  until exitloop
  return pn + 1
end

-- Return stack
dictionary['i'] = function () push(stack, rstack[#rstack]) end
dictionary['j'] = function () push(stack, rstack[#rstack-2]) end
dictionary['>r'] = function () push(rstack, pop(stack)) end
dictionary['r>'] = function () push(stack, pop(rstack)) end
dictionary['r@'] = function () push(stack, rstack[#rstack]) end

-- Other
dictionary['cr'] = function () io.write('\n') end
dictionary['emit'] = function () io.write(string.char(pop(stack))) end
dictionary['quit'] = function () os.exit() end

-- Run
if arg[1] then
  -- evaluate file
  local f = io.open(arg[1])
  if f then
    local txt = f:read('a')
    f:close()
    eval(txt, 1)
    io.write(' ok\n')
  else
    print(arg[1], 'not found')
  end
else
  -- read command line
  print('Enter the Forth expression, "quit" to exit')
  while true do
    local input = io.read()
    eval(input, 1)
    io.write(' ok\n')
  end
end

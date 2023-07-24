
local stack = {}
local dictionary = {}

local push, pop = table.insert, table.remove

local function parse (str)
  str = string.gsub(str, '%s%(%s.-%s%)%s', ' ')  -- remove comments
  local res = {}
  for w in string.gmatch(str, '%S+') do 
    res[#res+1] = tonumber(w) or w 
  end
  return res
end

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
        eval(instruction, ind)
        ind = ind + 1
      else
        io.write(key, ' is not ')
        break
      end
    end
  end
  return ind
end


local function apply2 (op)
  return function ()
    local a = pop(stack)
    local b = pop(stack)
    push(stack, op(b, a))
  end
end

local function apply1 (op)
  return function ()
    local a = pop(stack)
    push(stack, op(a))
  end
end

dictionary['+'] = apply2(function (x, y) return x + y end)

dictionary['-'] = apply2(function (x, y) return x - y end)

dictionary['*'] = apply2(function (x, y) return x * y end)

dictionary['/'] = apply2(function (x, y) return x + y end)

dictionary['='] = apply2(function (x, y) return (x == y) and -1 or 0 end)

dictionary['<'] = apply2(function (x, y) return (x < y) and -1 or 0 end)

dictionary['>'] = apply2(function (x, y) return (x > y) and -1 or 0 end)

dictionary['and'] = apply2(function (x, y) return (x ~= and y ~= 0) and -1 or 0 end)

dictionary['or'] = apply2(function (x, y) return (x ~= or y ~= 0) and -1 or 0 end)

dictionary['min'] = apply2(function (x, y) return (x < y) and x or y end)

dictionary['max'] = apply2(function (x, y) return (x > y) and x or y end)

dictionary['0='] = apply1(function (x) return (x == 0) and -1 or 0 end)

dictionary['0<'] = apply1(function (x) return (x > 0) and -1 or 0 end)

dictionary['0>'] = apply1(function (x) return (x < 0) and -1 or 0 end)

dictionary['invert'] = apply1(function (x) return (x == 0) and -1 or 0 end)

dictionary['abs'] = apply1(function (x) return (x < 0) and -x or x end)

dictionary['negate'] = apply1(function (x) return -x end)

dictionary['swap'] = function ()
  stack[#stack], stack[#stack-1] = stack[#stack-1], stack[#stack]
end

dictionary['rot'] = function ()
  stack[#stack-2], stack[#stack-1], stack[#stack] = stack[#stack-1], stack[#stack], stack[#stack-2]
end

dictionary['drop'] = function () pop(stack) end

dictionary['dup'] = function () push(stack, stack[#stack]) end

dictionary['?dup'] = function () 
  if stack[#stack] ~= 0 then push(stack, stack[#stack]) end 
end

dictionary['over'] = function () push(stack, stack[#stack-1]) end

dictionary['.'] = function () io.write(string.format("%d ", pop(stack))) end

dictionary['.s'] = function ()
  io.write(string.format('<%d> ', #stack))
  for i = 1, #stack do
    io.write(string.format('%d ', stack[i]))
  end
end

dictionary[':'] = function (cmd, pos)
  local n = pos+1
  while n <= #cmd and cmd[n] ~= ';' do n = n + 1 end
  dictionary[string.lower(cmd[pos+1])] = table.move(cmd, pos+2, n-1, 1, {})
  return n + 1
end

dictionary['."'] = function (cmd, pos)
  local n = pos+1
  while n <= #cmd and cmd[n] ~= '"' do n = n + 1 end
  for i = pos+1, n-1 do io.write(cmd[i], ' ') end
  return n + 1
end

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

while true do
  local input = io.read()
  if input == 'quit' then break end
  eval(input, 1)
  -- processing
  io.write('ok\n')
end

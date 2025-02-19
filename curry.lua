--[[  curry.lua

Apply currying to a regular Lua function.

2025, Stanislav Mikhel]]


--- Evaluate or make function with one argument.
--  @param x New argument for the function.
--  @param fn Function for evaluation.
--  @param args List of arguments.
--  @param tot Total number of the function arguments.
--  @return found value of a new function.
local function wrap (fn, args, x, tot)
  local state = {}
  for i = 1, #args do state[i] = args[i] end
  state[#state+1] = x
  if #state >= tot then
    -- evaluate
    return fn(table.unpack(state))
  else
    -- make new function
    return function (y)
      return wrap(fn, state, y, tot)
    end
  end
end

--- Transform f(x,y,z) to f'(x)(y)(z).
--  @param fn Function for currying.
--  @param nargs (=nil) Number of arguments.
--  @return function of 1 argument.
local function curry (fn, nargs)
  -- get number of arguments
  nargs = nargs or debug.getinfo(fn, 'u').nparams
  -- make curried
  return function (x)
    return wrap(fn, {}, x, nargs)
  end
end

--- Transform f(x)(y)(z) to f'(x, y, z).
--  @param fn Function for uncurrying.
--  @return function of several arguments.
local function uncurry (fn)
  return function (...)
    -- make uncurryied
    local t = fn
    for _, v in ipairs({...}) do
      t = t(v)
    end
    return t
  end
end


if arg[0] == "curry.lua"
then
--[[ Example ]]

-- Function to test
local add = function (x, y, z)
  return x + y + z
end
print(add (1, 2, 3))

-- Explicit currying
local add1 =
         function (x)
  return function (y)
  return function (z)
    return x + y + z
  end
  end
end
print(add1 (1) (2) (3))

-- Apply to ordinary function
local add2 = curry(add)
print(add2 (1) (2) (3))

-- Apply to curryed function
local add3 = uncurry(add2)
print (add3 (1, 2, 3))


--[[ Make library ]]
else return {
  curry = curry,
  uncurry = uncurry
} end

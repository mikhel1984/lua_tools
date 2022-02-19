--[[ behavior_trees.lua

Implementation of several components of the behavior trees.
Actions and conditions are the Lua funcitons, other 
components are implemented with tables and methamethods.
Example of application based on the Tower of Hanoi problem.

2022, Stanislav Mikhel ]]

-- child status
Status = {
  FAILURE = 0,
  SUCCESS = 1,
  RUNNING = 2
}

-- on call sequence
local mt_sequence = {
  __call = function (list) 
    for i = 1, #list do
      local res = list[i]()
      if res ~= Status.SUCCESS then 
        return res
      end
    end
    return Status.SUCCESS
  end
}
-- on call fallback
local mt_fallback = {
  __call = function (list)
    for i = 1, #list do
      local res = list[i]()
      if res ~= Status.FAILURE then
        return res
      end
    end
    return Status.FAILURE
  end
}
-- on call parallel
local mt_parallel = {
  __call = function (list)
    local suc, fail = 0, 0
    for i = 1, #list do
      local res = list[i]()
      if res == Status.SUCCESS then
        suc = suc + 1
      elseif res == Status.FAILURE then
        fail = fail + 1
      end
    end
    if suc >= list.minimum then
      return Status.SUCCESS
    elseif fail > #list - list.minimum then
      return Status.FAILURE
    end
    return Status.RUNNING
  end
}
-- on call decorator-invert
local mt_dec_invert = {
  __call = function (list)
    local res = list[1]()
    if res == Status.SUCCESS then 
      return Status.FAILURE
    elseif res == Status.FAILURE then 
      return Status.SUCCESS
    end
    -- Status.RUNNING - ?
  end
}
-- on call decorator-max-n
local mt_dec_max_n = {
  __call = function (list)
    local i = 0
    repeat
      local res = list[1]()
      if res == Status.FAILURE then 
        i = i + 1
      end
    until i >= list.N
    return Status.FAILURE
  end
}

-- call children untill failed
function Sequence(t) return setmetatable(t, mt_sequence) end

-- call children untill success
function Fallback(t) return setmetatable(t, mt_fallback) end

-- call all children
function Parallel(t) 
  assert(t.minimum and t.minimum > 0 and t.minimum <= #t) 
  return setmetatable(t, mt_parallel) 
end

-- child decorator
Decorator = {
  -- invert child value
  Invert = function (t) 
    assert(#t == 1) 
    return setmetatable(t, mt_dec_invert) 
  end, 
  -- call child N times max
  MaxN = function (t) 
    assert(#t == 1 and t.N and t.N >= 0) 
    return setmetatable(t, mt_dec_max_n) 
  end,
}

--
--======================== Tower of Hanoi ======================
--                          ( example )

-- rods
local rod1, rod2, rod3 = {}, {}, {}
-- number of discs
local discs = 4

-- fill the first rod 
for i = discs, 1, -1 do rod1[#rod1+1] = i end

-- wrap boolean result
local function stat(v) 
  return v and Status.SUCCESS or Status.FAILURE 
end

--        subtrees 
-- 1 -> 2 or 2 -> 1
local move12 = Fallback {
  Sequence {
    -- condition
    function () return stat(#rod2 == 0 or #rod1 > 0 and rod2[#rod2] > rod1[#rod1]) end, 
    -- actions 
    function () print('1 -> 2'); return Status.SUCCESS end,
    function () table.insert(rod2, table.remove(rod1)); return Status.SUCCESS end
  },
  Sequence {
    -- actions
    function () print('2 -> 1'); return Status.SUCCESS end,
    function () table.insert(rod1, table.remove(rod2)); return Status.SUCCESS end
  }
}
-- 1 -> 3 or 3 -> 1
local move13 = Fallback {
  Sequence {
    -- condition
    function () return stat(#rod3 == 0 or #rod1 > 0 and rod3[#rod3] > rod1[#rod1]) end, 
    -- actions 
    function () print('1 -> 3'); return Status.SUCCESS end,
    function () table.insert(rod3, table.remove(rod1)); return Status.SUCCESS end
  },
  Sequence {
    -- actions
    function () print('3 -> 1'); return Status.SUCCESS end,
    function () table.insert(rod1, table.remove(rod3)); return Status.SUCCESS end
  }
}
-- 2 -> 3 or 3 -> 2
local move23 = Fallback {
  Sequence {
    -- condition
    function () return stat(#rod3 == 0 or #rod2 > 0 and rod3[#rod3] > rod2[#rod2]) end, 
    -- actions 
    function () print('2 -> 3'); return Status.SUCCESS end,
    function () table.insert(rod3, table.remove(rod2)); return Status.SUCCESS end
  },
  Sequence {
    -- actions
    function () print('3 -> 2'); return Status.SUCCESS end,
    function () table.insert(rod2, table.remove(rod3)); return Status.SUCCESS end
  }
}

-- check number of rods
local function isEven() return stat(discs % 2 == 0) end
-- check final condition
local function isFinish() return stat(#rod3 == discs) end

-- solution
local mainLoop = 
-- do motions and check result
Sequence {
  -- choose one of two combinations
  Fallback {
    -- even number
    Sequence {
      isEven,
      -- actions 
      Fallback{ isFinish, move12 },
      Fallback{ isFinish, move13 },
      Fallback{ isFinish, move23 }
    }, 
    -- odd number
    Sequence {
      -- actions
      Fallback{ isFinish, move13 },
      Fallback{ isFinish, move12 },
      Fallback{ isFinish, move23 }
    }
  }, 
  function () print('Rods:',#rod1, #rod2, #rod3); return Status.SUCCESS end,
  isFinish
}

-- run 
while mainLoop() == Status.FAILURE do end


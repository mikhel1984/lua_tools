#!/usr/local/bin/lua
--[[    circle.lua

Print the circle of fifths.
Usage:
  ./circle [key]
E.g.
  ./circle
  ./circle Am
  ./circle '###'

2024, Stanislav Mikhel ]]

-- prepare
local maj = {
  'C  ', 'G  ', 'D  ', 'A  ', 'E  ', 'B  ',
  'Gb ', 'Db ', 'Ab ', 'Eb ', 'Bb ', 'F  '
}
local min = {
  'Am ', 'Em ', 'Bm ', 'F#m', 'C#m', 'G#m',
  'Ebm', 'Bbm', 'Fm ', 'Cm ', 'Gm ', 'Dm '
}

local function ln (...) print(string.format(...)) end
local function map (n) return (n > 12) and (n - 12) or (n < 1) and (n + 12) or n end
local function smaj (n) return maj[map(n)] end
local function smin (n) return min[map(n)] end

-- check names
local function search(x, t) 
  for i, v in ipairs(t) do
    if x == v:match('%S+') then
      return i
    end
  end
end
-- check signs
local function signs(x, s)
  local i = 0
  for v in x:gmatch('.') do
    if v == s then i = i + 1 else break end
  end
  if i > 0 then
    return (s == '#') and map(1+i) or map(1-i)
  end
end

local a, n = arg[1], 1
if a then
  n = search(a, maj) or search(a, min) or signs(a, '#') or signs(a, 'b') or 1
end

-- show
ln('               %s',             smaj(n))
ln('      4        1        5')
ln('        %s    %s    %s',        smaj(n-1), smin(n), smaj(n+1))
ln('          %s  6    %s',         smin(n-1), smin(n+1))
ln('  %s       2     3         %s', smaj(n-2), smaj(n+2))
ln('      %s               %s',     smin(n-2), smin(n+2))
ln('')
ln('%s %s                   %s %s', smaj(n-3), smin(n-3), smin(n+3), smaj(n+3))
ln('')
ln('      %s               %s',     smin(n-4), smin(n+4))
ln('  %s                       %s', smaj(n-4), smaj(n+4))
ln('          %s       %s',         smin(n-5), smin(n+5))
ln('        %s    %s    %s',        smaj(n-5), smin(n-6), smaj(n+5))
ln('')
ln('               %s',             smaj(n-6))

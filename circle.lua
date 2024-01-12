#!/usr/local/bin/lua
--[[    circle.lua

Print the circle of fifths.
Usage:
  ./circle [key]

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
local function imaj (n) return maj[map(n)] end
local function imin (n) return min[map(n)] end

local n = 1
-- check argument
local a = arg[1]
if a then
  -- major
  for i, v in ipairs(maj) do
    if a == v:match('%S+') then
      n = i
      break
    end
  end
  -- minor
  for i, v in ipairs(min) do
    if a == v:match('%S+') then
      n = i
      break
    end
  end
end

-- show
ln('               %s',             imaj(n))
ln('      4        1        5')
ln('        %s    %s    %s',        imaj(n-1), imin(n), imaj(n+1))
ln('          %s  6    %s',         imin(n-1), imin(n+1))
ln('  %s       2     3         %s', imaj(n-2), imaj(n+2))
ln('      %s               %s',     imin(n-2), imin(n+2))
ln('')
ln('%s %s                   %s %s', imaj(n-3), imin(n-3), imin(n+3), imaj(n+3))
ln('')
ln('      %s               %s',     imin(n-4), imin(n+4))
ln('  %s                       %s', imaj(n-4), imaj(n+4))
ln('          %s       %s',         imin(n-5), imin(n+5))
ln('        %s    %s    %s',        imaj(n-5), imin(n-6), imaj(n+5))
ln('')
ln('               %s',             imaj(n-6))

#!/usr/local/bin/lua
--[[    backup.lua

Generate chords for guitar or other musical instrument with strings. 
Usage: 
  ./chords.lua chordName parameters

2021, Stanislav Mikhel ]]

-- notes
  C, Db, D, Eb, E, F, Gb, G, Ab, A, Bb, B 
= 0,  1, 2,  3, 4, 5,  6, 7,  8, 9, 10, 11 

-- settings
local TUNING = {E, A, D, G, B, E}   -- open strings
local FRETS = 12                    -- length of fretboard
local FINGERS = 4                   -- # of finters for pressing strings

-- width configuration 
local pos1, frets1 = 1, 4     -- first position and 'maximal' width
local pos2, frets2 = 7, 5     -- second position and 'maximal' width
local WIDTHK = (frets2 - frets1) / (pos2 - pos1) 
local WIDTHB = (pos2 * frets1 - pos1 * frets2) / (pos2 - pos1)

-- list of chord types in C key
local chordSounds = {
  M  = {C, E, G},
  m   = {C, Eb, G},
  sus2  = {C, D, G},
  sus4  = {C, F, G},
  dim   = {C, Eb, Gb},
  aug   = {C, E, Ab},
  ["5"] = {C, G},
  ["6"] = {C, E, G, A},
  min6  = {C, Eb, G, A},
  ["7"] = {C, E, G, Bb},
  maj7  = {C, E, G, B},
  min7  = {C, Eb, G, Bb},
  ["9"] = {C, E, G, Bb, D},
  maj9  = {C, E, G, B, D},
  min9  = {C, Eb, G, Bb, D},
  ["11"] = {C, E, G, Bb, D, F},
  maj11 = {C, E, G, B, D, F},
  min11 = {C, Eb, G, Bb, D, F},
  ["13"] = {C, E, G, Bb, D, A},
  maj13 = {C, E, G, B, D, A},
  min13   = {C, Eb, G, Bb, D, A},
  add9  = {C, E, G, D},
  minadd9 = {C, Eb, G, D},
  min7b5 = {C, Eb, Gb, Bb},
  dim7   = {C, Eb, Gb, A},
  ["7sus4"] = {C, F, G, Bb},
  minmaj7 = {C, Eb, G, B},
  ["7aug"] = {C, E, Ab, Bb},
}

-- notes can be skipped, in C key
local n5, n15, n159 = {G}, {C, G}, {C, G, D}        

local canSkip = {
  -- 5th
  ["7"] = n5, maj7 = n5, min7 = n5, 
  -- 1st, 5th
  ["9"] = n15, maj9 = n15, min9 = n15, 
  -- 1st, 5th, 9th
  ["11"] = n159, maj11 = n159, min11 = n159,
  ["13"] = n159, maj13 = n159, min13 = n159,
}
setmetatable(canSkip, {__index = function () return {} end})

-- "comfortable" number of frets
local function getWidth(n) 
  local w = n * WIDTHK + WIDTHB 
  return (w - math.floor(w) > 0.5) and math.ceil(w) or math.floor(w) 
end

-- prepare 'mask' for the note comparison
local function fillMask(lst,notes)
  for i = 0,11 do lst[i] = false end            -- clear
  for _,v in ipairs(notes) do lst[v] = true end -- fill
  return lst
end

-- check if the string contains any sequence from the list
local function findPart(str, seq, pos)
  for _,v in ipairs(seq) do
    if string.find(str, '^'..v, pos) then 
      return v, pos + #v
    end
  end
  return nil, pos
end

-- exit if the value does not exist
function CRITICAL (v, txt)
  if not v then 
    print(txt or "Unknown chord!")
    os.exit()
  end
  return v
end

-- main variables and methods for generation
local fretboard = {
  fretboard = {}, -- sounds
  -- weights (metrics) for sorting
  W_STRINGS = 0.7,  -- not all strings
  W_BARRE = 1,      -- use barre
  W_NARROW = 0.5,   -- wide chord
  W_SYM = 0.6,      -- fingers are dispersed
  W_MAIN = 2,       -- lowest note is not root
  W_FULL = 1,       -- skip some notes
  -- positions
  subst = {['5'] = 3, ['7'] = 4, ['9'] = 5, ['11'] = 6, ['13'] = 6},
  -- alteration
  alt = {['#'] = 1, ['b'] = -1},
  -- aliases
  alias = {['Cb'] = 'B', ['C#'] = 'Db', ['D#'] = 'Eb', ['E#'] = 'F', 
    ['Fb'] = 'E', ['F#'] = 'Gb', ['G#'] = 'Ab', ['A#'] = 'Bb', ['B#'] = 'C'},
}

-- find number for the chord name
fretboard.getRoot = function (v)
  v = fretboard.alias[v] or v 
  return _ENV[v]
end

-- prepare fretboard strings
fretboard.fill = function ()
  local mask = fillMask({}, fretboard.cmd_chord)
  for i,v in ipairs(TUNING) do
    local sg = {}
    for j = 0, FRETS do
      local n = (v + j) % 12 
      if mask[n] then sg[j] = n end
    end
    fretboard.fretboard[i] = sg
  end
end

-- check if the current sequence of notes is a chord
fretboard.isChord = function (seq, ch, skip)
  for _,v in ipairs(ch) do
    if not (seq[v] or skip[v]) then return false end
  end
  return true
end

-- iterator for the string combinations
fretboard.nextSequence = function (var) 
  local total, last = 1, 0
  -- find number of combinations
  for i = 1, #var do total = total * (#var[i]) end
  -- generator
  return function () 
    while last < total do
      last = last + 1
      local strings, sounds, v = {}, {}, last
      -- current elements
      for i,seq in ipairs(var) do     -- for each string
        local m = seq[(v % #seq)+1]   -- find 'next' sound
        strings[i] = m
        sounds[#sounds+1] = fretboard.fretboard[i][m]
        v = v // #seq
      end
      return strings, sounds
    end
    -- exit
    return nil
  end
end

-- find all available chords
fretboard.generate = function ()
  local acc, notes = {}, {}
  local skipNotes = fillMask({}, fretboard.cmd_skip)
  -- for all positions
  for i = 1, FRETS do
    -- prepare variants 
    local variants = {} 
    local width = getWidth(i) - 1
    -- get sounds
    for j = 1, #fretboard.fretboard do 
      local string = fretboard.fretboard[j]
      local var = {'x'}                      -- muted string
      if string[0] then var[#var+1] = 0 end  -- open string
      for k = 0, width do
        if string[i+k] then var[#var+1] = i+k end
      end
      variants[j] = var
    end
    -- find sequence 
    for strings, sounds in fretboard.nextSequence(variants) do
      fillMask(notes, sounds)
      -- check and save
      if fretboard.isChord(notes, fretboard.cmd_chord, skipNotes) 
          and fretboard.isFeasible(strings) then 
        acc[ table.concat(strings,'-') ] = strings
      end
    end
  end
  return acc
end

-- print found chords into columns
fretboard.printCols = function (lst)
  local cols, n = 4, 0
  for i,v in ipairs(lst) do
    n = n + 1
    io.write(string.format("%-22s", table.concat(v,'-')))
    if n == cols then   
      io.write('\n')
      n = 0
    end
    -- empty line after each 10 rows
    if i % (cols*10) == 0 then print() end
  end
  print()
end

-- show fretboard
fretboard.print = function ()
  local N = #fretboard.fretboard
  for i = N,1,-1 do 
    local s = fretboard.fretboard[i]
    io.write(N-i+1,') ')
    io.write(s[0] and string.format("%2d", s[0]) or ' .', '|')
    for i = 1, FRETS do
      --io.write(s[i] or '.', ' ')
      io.write(s[i] and string.format("%2d", s[i]) or ' .', ' ')
    end
    print()
  end
  io.write('FR:',' 0 ')
  for i = 1, FRETS do
    if i % 3 == 0 then
      io.write(string.format("%2d", i), ' ')
    else 
      io.write(' * ')
    end
  end
  print()
end

-- check if the chord is feasible
fretboard.isFeasible = function (strings)
  local n = 0
  for _,v in ipairs(strings) do 
    if not (v == 'x' or v == 0) then n = n+1 end 
  end
  if n <= FINGERS then return true end  
  -- find groups (sequence of strings for barre)
  local grp, inGrp = {}, {}
  for i,v in ipairs(strings) do
    if not (v == 'x' or inGrp[i]) then
      for j = i+1, #strings do
        if v == strings[j] then 
          -- check intersection
          local intersect = false
          for k = i+1, j-1 do 
            local w = strings[k] 
            if w ~= 'x' and w < v then 
              intersect = true 
              break
            end
          end
          -- add group
          if not intersect then
            inGrp[j] = true
            if #grp > 0 and grp[#grp][1] == i then 
              table.insert(grp[#grp], j)  -- append 
            else
              grp[#grp+1] = {i,j}         -- add new
            end
          end -- if not 
        end -- if v
      end -- for j
    end -- if not
  end
  -- check sounds with barre
  local f = FINGERS
  for _, v in ipairs(grp) do
    n = n - #v  -- rest of notes
    f = f - 1   -- rest of fingers
  end
  return n <= f -- compare sounds and fingers
end

-- compare chord weights
fretboard.sortChords = function (acc)
  local list = {}
  for k,v in pairs(acc) do 
    local w, pos = fretboard.weight(v, fretboard.cmd_chord)
    v.w = w
    v.pos = pos
    list[#list+1] = v 
  end
  table.sort(list, function (x,y) 
      return (x.w == y.w) and x.pos < y.pos or x.w > y.w 
    end)
  return list  
end

fretboard.thinChords = function (acc)
  local res = {}
  for k,v in pairs(acc) do
    local skip = false
    skip = skip or (fretboard.cmd_no_open 
                     and (string.sub(k,1,1) == '0' or string.find(k,'-0'))) 
    skip = skip or (fretboard.cmd_no_muted and string.find(k,'x'))
    if not skip and fretboard.cmd_no_barre then
      local n = 0
      for _,s in ipairs(v) do
        if s ~= 'x' and s > 0 then n = n + 1 end
      end
      skip = (n > FINGERS)
    end
    if not skip then res[k] = v end  
  end
  return res
end

-- metrics for chords comparison
fretboard.weight = function (strings, chord)
  local total = 10   -- 'maximal' weight
  --> number of sounds 
  local n, m = 0, 0
  for _,v in ipairs(strings) do 
    if v ~= 'x' then 
      m = m+1                      -- # of sounds
      if v > 0 then n = n + 1 end  -- # of pressed strings
    end 
  end
  total = total - (#strings - m)*fretboard.W_STRINGS  -- prefer all strings
  if n > FINGERS then 
    total = total - fretboard.W_BARRE                 -- prefer open chords
  end
  --> width
  local fmin, fmax = math.huge, -1
  local ic, fc = 0, 0
  for i,v in ipairs(strings) do
    if v ~= 'x' and v > 0 then
      if v < fmin then fmin = v end
      if v > fmax then fmax = v end
      -- collect location data
      ic = ic + i
      fc = fc + v
    end
  end
  total = total - (fmax - fmin)*fretboard.W_NARROW  -- prefer narrow chords 
  --> symmetry
  if n > 0 then
    -- 'central' point
    ic = ic / n
    fc = fc / n
    local di, df = 0, 0
    for i,v in ipairs(strings) do
      if v ~= 'x' and v > 0 then 
        di = di + (i - ic)^2
        df = df + (v - fc)^2
      end
    end
    -- avoid divide by zero 
    di, df = di + 1E-5, df + 1E-5
    -- estimate 
    total = total - math.abs(di-df)/(di+df)*fretboard.W_SYM  -- prefer "symmetric" chords
  end
  --> inversion 
  for i,v in ipairs(strings) do
    if v ~= 'x' then
      if fretboard.fretboard[i][v] ~= chord[1] then 
        total = total - fretboard.W_MAIN              -- prefer main form
      end
      break
    end
  end
  --> find skipped
  local rest = {}
  for _,v in ipairs(chord) do rest[v] = true end
  for i,v in ipairs(strings) do 
    local k = fretboard.fretboard[i][v] 
    if rest[k] then rest[k] = nil end
  end
  local r = 0
  for i = 1,12 do 
    if rest[i] then r = r + 1 end
  end
  total = total - r*fretboard.W_FULL                 -- prefer full chords
  -- weight and position 
  return total, fmin  
end

-- get chord name and type
fretboard.parseChord = function (str)
  local p, val = 1
  -- find root
  val, p = findPart(str, {'Cb','C#','C','Db','D#','D','Eb','E#','E','F#','Fb','F','Gb','G#','G','Ab','A#','A','Bb','B#','B'}, p) 
  local root = fretboard.getRoot(CRITICAL(val)) 
  -- prepare type list
  local types = {}
  for k,_ in pairs(chordSounds) do types[#types+1] = k end
  table.sort(types, function (x,y) return x > y end)
  local sounds, skip = {}, {}
  -- find type
  if p <= #str then 
    val, p = findPart(str, types, p)
    sounds = chordSounds[CRITICAL(val)]
    skip   = canSkip[val]
  else 
    sounds = chordSounds.M
  end
  -- update sounds
  for i = 1, #sounds do sounds[i] = (sounds[i] + root) % 12 end
  for i = 1, #skip do skip[i] = (skip[i] + root) % 12 end
  -- alterations
  while p < #str do
    local alt = CRITICAL(fretboard.alt[ string.sub(str,p,p) ])
    local ind = CRITICAL(fretboard.subst[ string.sub(str,p+1,p+1) ])
    sounds[ind] = (CRITICAL(sounds[ind], "Wrong sounds!") + alt) % 12
    p = p + 2
  end
  return sounds, skip
end

-- change open strings
fretboard['--tuning'] = function (n)
  local res = {}
  while n <= #arg do
    local v = arg[n]
    if v and string.sub(v,1,1) ~= '-' then 
      res[#res+1] = CRITICAL(fretboard.getRoot(v), "Unexpected sound "..v)
    else
      break
    end
    n = n + 1
  end
  if #res > 0 then TUNING = res end 
  return fretboard.parse(n)
end

-- change fret number
fretboard['--frets'] = function (n)
  local v = arg[n]
  if v then FRETS = tonumber(v) end
  return fretboard.parse(n+1)
end

-- skip chords with open strings
fretboard['--no-open'] = function (n)
  fretboard.cmd_no_open = true
  return fretboard.parse(n)
end

-- skip chords with muted strings
fretboard['--no-muted'] = function (n)
  fretboard.cmd_no_muted = true 
  return fretboard.parse(n)
end

-- skip chords with barre
fretboard['--no-barre'] = function (n)
  fretboard.cmd_no_barre = true
  return fretboard.parse(n)
end

-- show fretboard notes
fretboard['--fb'] = function (n)
  fretboard.cmd_fb = true
  return fretboard.parse(n)
end

-- parse command line input
fretboard.parse = function (n)
  n = n or 1
  local v = arg[n]
  if not v then
      if n == 1 then fretboard.usage() end
      return
  end
  if n == 1 then 
    local chord, skip = fretboard.parseChord(v)
    fretboard.cmd_chord = chord
    fretboard.cmd_skip = skip
    return fretboard.parse(2)
  elseif CRITICAL(fretboard[v],"Wrong parameter "..v) then 
    return fretboard[v](n+1) 
  end
end

-- help
fretboard.usage = function ()
  local keys = {'Db','D','Eb','E','F','Gb','G','Ab','A','Bb','B',[0]='C'}
  print "Usage: ./chords.lua chord [params] "
  print "  chord - valid chord name"
  print "  params - list of keys and values"
  print "Examples:"
  print "  --frets 5 - fret number is 5"
  print "  --tuning G C E A  - use ukulele tuning" 
  print "  --no-open - skip chords with open strings"
  print "  --no-muded - skip chords with muted strings"
  print "  --no-barre - skip chords with barre"
  print "  --fb - show sounds on the fretboard"
  print("Current frets number: "..tostring(FRETS))
  local tbl = {}
  for i,v in ipairs(TUNING) do tbl[i] = keys[v] end 
  print("Current tuning: {"..table.concat(tbl,' ')..'}')
  tbl = {}
  for k in pairs(chordSounds) do tbl[#tbl+1] = k end
  print("Chord types: "..table.concat(tbl,', '))
  os.exit()
end

-- initial point
fretboard.main = function ()
  -- read command line
  fretboard.parse()    -- result in 'cmd_chord' and 'cmd_skip'
  -- prepare fretboard
  fretboard.fill() 
  -- show fretboard
  if fretboard.cmd_fb then fretboard.print() end
  -- chord list 
  local lst = fretboard.generate()
  -- check flags
  lst = fretboard.thinChords(lst)
  -- apply metrics
  lst = fretboard.sortChords(lst)
  -- show result
  fretboard.printCols(lst)
end

-- run
fretboard.main()

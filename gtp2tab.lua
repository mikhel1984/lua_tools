--[[ 		gtp2tab.lua

Read Guitar Pro v4.0 files and save track using pseudo graphic.

Usage:
   lua gtp2tab.lua file         -- get information about the file
   lua gtp2tab.lua file track   -- save current track as a text file

2018, Stanislav Mikhel ]]

if not arg[1] then print(
[[Usage:
    lua gtp2tab.lua file        -- get info about file
    lua gtp2tab.lua file track  -- save current track to new file ]])
    os.exit()
end

--=================== DEFINITIONS ===================

local position = 2 -- start position
local gp4          -- global file variable

local bit = {0x2, 0x4, 0x8, 0x10, 0x20, 0x40, 0x80}; bit[0] = 0x1
local EMPTY = '---'
local beat_dur = {8,16,32,64,128}; beat_dur[0] = 4; beat_dur[-1] = 2; beat_dur[-2] = 1
local tune = {'C#','D ','D#','E ','F ','F#','G ','G#','A ','A#','H '}; tune[0] = 'C '

-- get value of "integer"
local function int ()
   --!! use only first byte
   local res =  string.byte(gp4,position) 
   position = position + 4
   return res
end
-- get unsigned value of byte
local function byte ()
   local res = string.byte(gp4,position)
   position = position + 1
   return res
end
-- get signed value of byte
local function sbyte ()
   local v = byte()
   return (v < 128) and v or (v-256)
end
-- color requires 4 bytes (just read)
local function color()
   position = position + 4
end
-- read string
local function str ()
   local l = int()  -- string length
   local res = string.sub(gp4,position+1,position+l-1)
   position = position + l
   return res
end

-- save info about composition here
local info = {}

-- get information about chord (just read)
local function get_chord()
   byte()                 -- header
   byte()                 -- sharp
   byte(); byte(); byte() -- blank
   sbyte()                -- root
   byte()                 -- type
   byte()                 -- nine,eleven,thirteen
   int()                  -- bass
   int()                  -- dim/aug
   byte()                 -- add
   -- name
   position = position+1  -- eliminate number of letters
   -- print('Name',gp4:sub(position,position+19)); 
   position = position+20
   byte(); byte()         -- blank
   byte()                 -- fifth
   byte()                 -- ninth
   byte()                 -- element
   int()                  -- base fret
   -- frets
   for i = 1,7 do int() end
   byte()                 -- # of barres
   -- fret of barre
   for i = 1,5 do byte() end
   -- barre start
   for i = 1,5 do byte() end
   -- barre end
   for i = 1,5 do byte() end
   -- omission1, omission3 ... omission13
   byte(); byte(); byte(); byte(); byte(); byte(); byte()
   byte()                 -- blank
   -- fingering
   for i = 1,7 do byte() end
   byte()                 -- show fingering
end
-- get information about bend (just read)
local function get_bend()
   byte()                 -- type
   int()                  -- value
   local points = int()
   for i = 1,points do
      int()               -- absolute time position
      int()               -- vertical position
      byte()              -- vibrato
   end
end
-- get information about common effects (just read)
local function get_effects()
   local header1 = byte()
   local header2 = byte()
   -- tap / pop / slap
   if header1 & bit[5] ~= 0 then byte() end
   if header2 & bit[2] ~= 0 then get_bend() end
   -- upstroke
   if header1 & bit[6] ~= 0 then byte() end
   -- downstroke
   if header1 & bit[6] ~= 0 then byte() end
   --if header2 & bit[0] ~= 0 then end -- rasgueado
   -- pickstroke
   if header2 & bit[1] ~= 0 then byte() end
end
-- get information about sound change (just read)
local function get_mix()
   sbyte()                           -- instrument
   local vol = sbyte()               -- volume
   local pan = sbyte()               -- pan
   local chorus = sbyte()            -- chorus
   local revebr = sbyte()            -- revebration
   local phaser = sbyte()            -- phaser
   local trem = sbyte()              -- tremolo
   local tempo = int()               -- tempo
   -- change duration
   if vol ~= -1 then byte() end      -- volume
   if pan ~= -1 then byte() end      -- pan
   if chorus ~= -1 then byte() end   -- chorus
   if revebr ~= -1 then byte() end   -- revebration
   if phaser ~= -1 then byte() end   -- phaser
   if trem ~= -1 then byte() end     -- tremolo
   if tempo > 0 and tempo < 250 then byte() end -- tempo
   byte() -- define tracks
end
-- also just read
local function get_grace()
   byte()                 -- fret
   byte()                 -- dynamic
   byte()                 -- transition
   byte()                 -- duration
end
-- get information about effects for current note
local function get_note_effect(tbl)
   local header1 = byte()
   local header2 = byte()
   if header1 & bit[1] ~= 0 then tbl.effect = 'h' end      -- hammer
   if header1 & bit[2] ~= 0 then tbl.effect = 's' end      -- slide from
   if header1 & bit[3] ~= 0 then tbl.effect = '>' end      -- let ring
   if header2 & bit[0] ~= 0 then tbl.effect = '*' end      -- stoccato
   if header2 & bit[1] ~= 0 then tbl.effect = 'M' end      -- palm muting
   if header2 & bit[6] ~= 0 then tbl.effect = 'v' end      -- vibrato
   if header1 & bit[0] ~= 0 then get_bend(); tbl.effect = 'B' end -- bend
   if header1 & bit[4] ~= 0 then get_grace() end
   if header2 & bit[2] ~= 0 then byte() end                -- tremolo
   if header2 & bit[3] ~= 0 then sbyte(); tbl.effect = 's' end
   if header2 & bit[4] ~= 0 then byte() end                -- harmonics
   if header2 & bit[5] ~= 0 then byte(); byte() end        -- thrill
end
-- get information about current note
local function get_note()
   local res = {effect=' '}    -- no effects by default
   local header = byte()
   if header & bit[1] ~= 0 then res.effect = '.' end -- dotted
   if header & bit[2] ~= 0 then res.effect = 'x' end -- ghost
   --if header & bit[6] ~= 0 then end                -- accentuated
   if header & bit[5] ~= 0 then byte() end           -- note type
   if header & bit[0] ~= 0 then 
      sbyte()    -- duration
      byte()     -- tuplet
   end
   if header & bit[4] ~= 0 then byte() end           -- dynamic
   if header & bit[5] ~= 0 then res.fret = byte() end
   if header & bit[7] ~= 0 then
      byte()              -- left finger
      byte()              -- right finger
   end
   if header & bit[3] ~= 0 then get_note_effect(res) end
   -- to string
   return string.format('%2s%s', tostring(res.fret), res.effect)
end
-- get all notes for current beat
local function read_notes(tbl)
   -- get strings (represented as bits)
   local strings,S = byte(), {}
   -- find nonzero elements
   for i = 0,6 do S[i] = (strings & bit[i] ~= 0) end
   -- replace string representation
   for i = 6,0,-1 do
      if S[i] then tbl[i] = get_note() end
   end
end

-- collect strings for all strings and beats in measure
local function measure2str(tbl,n_str,marks)
   local res = {{},{},{},{},{},{},{},dur={}}
   local dpos = n_str > 5 and 5 or n_str    -- lower position of signs
   local npos = n_str > 3 and 2 or 1        -- upper position of signs
   -- add dimention
   if marks.num and marks.denom then
      for i = 1,n_str do 
         if     i == npos then table.insert(res[i], string.format('%2s ', marks.num))
	 elseif i == dpos then table.insert(res[i], string.format('%2s ', marks.denom))
	 else table.insert(res[i], '   ') end
      end
      table.insert(res.dur, ' : ')
   end
   -- reprise (begin)
   if marks.rep_begin then
      for i = 1,n_str do 
         if i == npos or i == dpos then table.insert(res[i], ' * ')
	 else table.insert(res[i], '   ') end
      end
      table.insert(res.dur, 'REP')
   end
   -- add beats
   for _,beat in ipairs(tbl) do
      -- add notes
      for n = 1,n_str do
         table.insert(res[n], beat[7-n])
      end
      table.insert(res.dur, string.format('/%-2s',tostring(beat.tuplet or beat.duration)))
   end
   -- reprise (end)
   if marks.rep_no then
      for i = 1,n_str do 
         if i == npos or i == dpos then table.insert(res[i], ' * ')
	 else table.insert(res[i], '   ') end
      end
      table.insert(res.dur, string.format('x%-2s', marks.rep_no))
   end
   -- set end of measure
   for n = 1,n_str do table.insert(res[n], '|') end
   table.insert(res.dur, ' ')
   -- concat strings, remove empty
   for i = 1,7 do
      if #res[i] ~= 0 then
         res[i] = table.concat(res[i])
      else
         res[i] = nil
      end
   end
   res.dur = table.concat(res.dur)
   -- return list of strings
   return res
end

--================== READ FILE =======================

local src = arg[1]    -- file name
local f = assert(io.open(src,'rb'), "Can't read file " .. src)
gp4 = f:read('*a')
f:close()

-- check file type
assert(gp4:sub(2,19) == 'FICHIER GUITAR PRO', 'Guitar Pro file is expected!')
position = position+30    -- file header
-- title
info[#info+1] = 'Title:  '..str()   
str()                     -- subtitle
str()                     -- interpret
-- albom
info[#info+1] = 'Albom:  '..str()     
-- author
info[#info+1] = 'Author: '..str()     
info[#info+1] = EMPTY
str()                     -- copyright
str()                     -- tab author
str()                     -- instruction
for i = 1, int() do       -- number of lines
   str()                  -- notes
end
-- triplet feel
if byte() > 0 then info[#info+1] = 'Triplet feel' end
-- lirics
int()                     -- lirics track number
for i = 1,5 do            -- lirics list
   int(); str()
end
-- tempo
info[#info+1] = 'Tempo:  '..int()
int()                     -- key
byte()                    -- octave
-- midi
for p = 1,4 do
   for c = 1,16 do
      int()  -- instrument
      byte()  -- volume
      byte()  -- balance 
      byte()  -- chorus
      byte()  -- revebr
      byte()  -- phaser
      byte()  -- tremolo
      -- blank
      byte(); byte();
   end
end
-- measures
local measures = int()
--print('Measures',measures)
-- tracks
local tracks = int()
--print('Tracks',tracks)

local header       -- header byte
local M_list = {}  -- information about each measure

for m = 1,measures do
   -- Measure content
   header = byte()
   local tmp = {}
   -- numerator
   if (header & bit[0]) ~= 0 then tmp.num = byte() end
   -- denominator
   if (header & bit[1]) ~= 0 then tmp.denom = byte() end
   -- begining of repeat
   if (header & bit[2]) ~= 0 then tmp.rep_begin = true end
   -- # of repeats
   if (header & bit[3]) ~= 0 then tmp.rep_no = byte() end
   -- # of alternating ending
   if (header & bit[4]) ~= 0 then tmp.end_no = byte() end
   -- marker
   if (header & bit[5]) ~= 0 then str(); color() end
   -- tonality
   if (header & bit[6]) ~= 0 then byte() end
   -- double bar
   --if (header & bit[7]) ~= 0 then end
   -- save
   M_list[m] = tmp
end

local T_list = {}    -- information about each track

for t = 1,tracks do
   local tmp = {}
   -- Track content
   header = byte()
   if (header & bit[0]) ~= 0 then tmp.drum = true end
   --if (header & bit[1]) ~= 0 then end -- 12 strings
   --if (header & bit[2]) ~= 0 then end  -- banjo
   -- track name
   position = position+1 -- eliminate number of letters
   tmp.name = gp4:sub(position,position+39); position = position+40
   -- kostyl
   while gp4:byte(position) == 0 do position = position+1 end
   tmp.str_no = int()           -- # of strings
   -- tuning
   tmp.strings = {}
   for s = 1,7 do tmp.strings[s] = int() end
   int()                        -- port
   int()                        -- channel
   int()                        -- channel E
   tmp.frets = int()            -- # of frets
   tmp.capo = int()             -- height of capo
   color()
   tmp.measures = {}            -- measure list for each track
   -- save
   T_list[t] = tmp
end

info[#info+1] = EMPTY
local info_str = table.concat(info,'\n')
-- show information
if not arg[2] then
   print(info_str)
   print('Tracks:')
   for i, track in ipairs(T_list) do
      -- show name and position
      print(string.format(' %d - %s %s', i, track.name, track.drum and '(drums)' or ''))
   end
   os.exit()
end

-- Measure-track pairs
for m = 1,measures do   
   for t = 1,tracks do      
      local beats = int()     -- # of beats 
      local B_list = {}       -- list of beats
      for b = 1,beats do
         -- beat notes
         local tmp = {EMPTY,EMPTY,EMPTY,EMPTY,EMPTY,EMPTY}
         -- header
         header = byte()
         --if (header & bit[0]) ~= 0 then end  -- dotted notes
         -- status
         if (header & bit[6]) ~= 0 then byte() end  -- status
         -- beat duration
         tmp.duration = beat_dur[sbyte()]
         -- N-tuplet
         if (header & bit[5]) ~= 0 then tmp.tuplet = int() end
         -- chord diagram
         if (header & bit[1]) ~= 0 then get_chord() end
         -- text
         if (header & bit[2]) ~= 0 then str() end
         -- effects
         if (header & bit[3]) ~= 0 then get_effects() end
         -- mix table
         if (header & bit[4]) ~= 0 then get_mix() end
         -- note
         read_notes(tmp)
         -- add result
         B_list[b] = tmp
      end -- beats
      -- combine notes for each string
      local M = measure2str(B_list, T_list[t].str_no, M_list[m])
      -- add to tracks
      table.insert(T_list[t].measures, M)
   end -- tracks
end -- measures

--======================== PRINT RESULT =========================

local N = tonumber(arg[2])   -- track number
local T = assert(T_list[N], 'No such track number: '..arg[2])
local M = T.measures

-- perapare new file
local nm1 = string.match(src, '(.+)%..+')
local newname = string.format('%s-%s.txt',nm1,arg[2])
f = io.open(newname, 'w')

-- head
f:write(info_str,'\n')
f:write('Track: ',T.name)
if T.drum then f:write('(drums)') end
f:write('\nFrets: ',T.frets,'\tCapo: ',T.capo,'\n')

-- write all measures for the given track
local txt, m = {}, 1
while m <= #M do
   if #txt == 0 then
      -- new "line", add strings
      for i = 1,#M[1] do txt[i] = tune[T.strings[i] % 12] end
      txt.dur = '  '
      f:write(string.format('(%d)\n',m))  -- # of measure
   end
   local lcurr, lnext = #txt[1], #M[m][1]

   if lcurr+lnext <= 80 or lcurr == 0 then
      for i = 1,#txt do txt[i] = txt[i] .. M[m][i] end
      txt.dur = txt.dur .. M[m].dur
      m = m+1
   else
      -- save current state 
      for i = 1,#txt do f:write(txt[i],'\n') end
      f:write(txt.dur,'\n\n')      
      txt = {}  -- run new "line"
   end
end
-- get rest
if #txt ~= 0 then
   for i = 1,#txt do f:write(txt[i],'\n') end
   f:write(txt.dur,'\n')
end

-- comments
f:write('\n\t\t\t\tMARKS\n')
f:write('h - hammer/pull\ts - slide\tv - vibrato \tB - bend\tM - palm mute\n')
f:write('. - dotted note\tx - ghost\t* - stoccato\t> - let ring\n')

-- finish
f:close()
print('Track is saved as '..newname)

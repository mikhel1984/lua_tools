#!/usr/local/bin/lua
--[[
   Simple tool for time management. Allows to set timer for work and rest.
   GUI is implemented in IUP.
]]

require 'iuplua'

-- time settings
WORK_TIME = 25  -- minutes
REST_TIME = 5   -- minutes

------------------------ 
counter = 0
WORK, REST = 1, 2
states = {
   -- work
   {t=WORK_TIME, txt=function() return 'Relax, man!' end, 
    lbl='Work', btn={'OK'}, inc=1},
   -- rest
   {t=REST_TIME, txt=function() return string.format('POMIDORS: %d    WORK TIME: %d', counter, counter * WORK_TIME) end,
    lbl='Rest', btn={'Continue','Break'}, inc=0}
}
current = REST
sec = 0
-- prepare strings with 'stars'
stars_no = 5
star_tbl = {}
for i = stars_no,1,-1 do
   star_tbl[i] = string.rep('*', i, ' ')
end

-- widgets
timer = iup.timer {time=1000}
lbl = iup.label {title='     Ready?'}
lbl2 = iup.label {title=''}
box = iup.vbox {lbl, lbl2}
dlg = iup.dialog {box; 
                  title='Pomidor', size='110x34', icon='pomidor.png'}
--lbl.alignment = 'ACENTER:ACENTER'
lbl.font = 'Sans, Bold 12'
lbl2.font = lbl.font

-- timer action
function timer:action_cb()
   -- update time
   sec = sec - 1
   -- check periods
   if sec <= 0 then
      -- if not the first time
      if stars then
         timer.run = 'NO'
         local b = iup.Alarm('Timer!', states[current].txt(),
                             table.unpack(states[current].btn))
         if b == 2 then return iup.CLOSE end
      end
      -- change state
      current = current % 2 + 1
      -- update parameters
      sec = 60 * states[current].t
      step = sec / stars_no
      stars = stars_no
      counter = counter + states[current].inc
      timer.run = 'YES'
   elseif sec < (stars-1)*step then
      stars = stars - 1
   end
   -- update time and title
   lbl.title = string.format('   %s - %d:%02d', states[current].lbl, sec // 60, sec % 60)
   lbl2.title = string.format('    Pomidor: %d ', counter)
   dlg.title = star_tbl[stars]
   return iup.DEFAULT
end

dlg:show()
timer.run = 'YES'

-- run programm
iup.MainLoop()

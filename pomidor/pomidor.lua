#!/usr/local/bin/lua

--[[		pomidor.lua

Simple tool for time management. 
Allows to create a list of task and use timer for work and rest.

2018, Stanislav Mikhel ]]

-- time settings
WORK_TIME = 25     -- minutes
RELAX_TIME = 5     -- minutes

-- GUI
require 'iuplua' 

-- constants
WIDTH = '160x'
POMIDOR,CURRENT,TOTAL = 'Pomidor: ','Current: ','Planned: '
message = {'Timer','Relax, man :)','Time to work!',{'Run next','Repeat','Skip next'},{'OK'}}
VPNG, XPNG = 'v.png', 'x.png'

-- list of states
status = {}

-- proxy
_status = {work=false, rest=0, stars=5, pomidor=0, current_time=0, total_time=0, task=0, task_no=0}
_status.onchange = {}                      -- methods to call when variable is modified
-- "rest"
_status.onchange.rest = function (v)
   if _status.work and v % 60 == 1 then    -- every minute
      _status.current_time = _status.current_time+1; update_time(_status.task) 
   end
   local ss = _status.stars-1
   if v < _status.step*ss then _status.stars = ss end
   return v
end
-- "work"
_status.onchange.work = function (v)
   if _status.step then                    -- not the first call
      if _status.work then 
         _status.pomidor = _status.pomidor+1
	 update_image(_status.task, VPNG)
         iup.Alarm(message[1],message[2],message[5][1]) 
      else 
         status.task=_status.task+1        -- find number of the next task
      end
   end
   _status.rest = 60*(_status.work and RELAX_TIME or WORK_TIME)
   _status.step = _status.rest / #stars
   _status.stars = #stars
   return v
end
-- "task_no"
_status.onchange.task_no = function (v)
   _status.total_time = v*WORK_TIME
   if _status.task == 0 then _status.task = 1 end
   return v
end
-- "task"
_status.onchange.task = function (v)
   local n = choosetask(v)                 -- run dialog with user
   update_image(n, XPNG)
   return (n > _status.task_no) and _status.task_no or n
end

-- set metamethods
-- reading
_status.__index = _status
-- writing
_status.__newindex = function (t,k,v)
    local fn = _status.onchange[k]
    if fn then v = fn(v) end
   _status[k] = v
end
setmetatable(status,_status)

-- recursive function for choosing next task
function choosetask(n)
   local txt,t = get_task(n)
   if #txt > 0 then
      txt,t = 'Next: '..txt, 4
   else
      txt,t = message[3], 5
   end
   local b = iup.Alarm(message[1], txt, table.unpack(message[t]))
   if     b == 1 then return n                     -- next
   elseif b == 2 then return choosetask(n-1)       -- repeat last
   elseif b == 3 then return choosetask(n+1)       -- skip next
   end
end

-- prepare 'stars' for title
stars = {}
for i = status.stars,1,-1 do stars[i] = string.rep('*',i,' ') end

-- new task line
function addtask()
   return iup.hbox {
      iup.text  {readonly='NO', expand='HORIZONTAL'},
      iup.label {title='0',size='17x',alignment='ACENTER'},
      iup.label {image='x.png'},
   }
end

-- Dialog elements
-- status and time
timeline = iup.vbox {
   iup.label {title='Ready?', font='Sans, Bold 12', expand='HORIZONTAL', alignment='ACENTER'},
   iup.label {title='', font='Sans, Bold 12', expand='HORIZONTAL', alignment='ACENTER'}
}
-- user tasks
tasklist = iup.vbox {}
-- control elements
buttons = iup.hbox {
   iup.button {title='Start', expand='HORIZONTAL'},
   iup.button {title='Add task', expand='HORIZONTAL'}
   ;size=WIDTH
}
-- time parameters and number of attempts
statusline = iup.hbox {
   iup.label {title=POMIDOR..0, expand='HORIZONTAL'},
   iup.label {title=CURRENT..0, expand='HORIZONTAL'},
   iup.label {title=TOTAL..0, expand='HORIZONTAL'}
}
-- combine
dlg = iup.dialog {
   iup.vbox {
      timeline,
      tasklist,
      buttons,
      statusline
   }
   ;title='Pomidor', icon='pomidor.png'
}

-- get task text
function get_task(n)
   local lbl = iup.GetChild(tasklist,n-1)
   return lbl and lbl[1].value or '' 
end
-- update task time
function update_time(task)
   local lbl = iup.GetChild(tasklist,task-1)
   if lbl then lbl[2].title = tostring(tonumber(lbl[2].title) + 1) end
end
-- update task status image
function update_image(task,im)
   local lbl = iup.GetChild(tasklist,task-1)
   if lbl then lbl[3].image = im end
end

-- create timer
timer = iup.timer {time=1000, run='NO'}      -- one second
-- start/pause 
buttons[1].action = function ()
   if timer.run == 'YES' then 
      timer.run = 'NO'; buttons[1].title = 'Start' 
   else 
      timer.run = 'YES'; buttons[1].title = 'Pause' 
   end
end
-- add new task
buttons[2].action = function ()
   local new = addtask()
   iup.Append(tasklist, new)
   iup.Map(new)
   iup.Refresh(tasklist)
   -- update parameters
   status.task_no = iup.GetChildCount(tasklist)
   statusline[3].title = TOTAL..status.total_time
   -- resize window
   dlg.size = dlg.usersize
   iup.Refresh(dlg)
end

-- timer callback
timer.action_cb = function (self)
   local sec = status.rest-1
   if sec <= 0 then
      timer.run = 'NO' 
      status.work = not status.work        -- execute main work here
      -- update text
      timeline[1].title = status.work and 'Work' or 'Relax'
      statusline[1].title = POMIDOR..status.pomidor
      -- continue
      timer.run = 'YES'
      sec = status.rest
   else
      status.rest = sec
   end
   timeline[2].title = string.format('%d:%02d', sec // 60, sec % 60)
   statusline[2].title = CURRENT..status.current_time
   dlg.title = stars[status.stars]
   return iup.DEFAULT
end

-- start
dlg:show()
iup.MainLoop()

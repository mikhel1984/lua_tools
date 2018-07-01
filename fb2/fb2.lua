--[[		fb2.lua

Simple transformation from plain text to fiction book format. The only feature it provides is producing a valid fb2 file.

Usage

* Prepare book description. Book title, author name and other information is represented as a Lua table in file "info.lua". 
* Prepare text file. Single text line between two blank lines is assumed as title, but it can be corrected by the line preffixes 
  (preffixes are punctuation characters and can be changed in "info.lua"). Multiline text is a paragraph. After that copy text 
  file into directory with this program. 
* Convert file. Open terminal and write command 
    
     lua fb2.lua your_file_name

As a result you will get file "your_file_name.fb2".

2017, Stanislav Mikhel ]]

-- Book description
local INFO = 'info.lua'
-- FB2 head
local HEAD = [[
<?xml version="1.0" encoding="{{encoding}}"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
   <description>
   <title-info>
      <genre>{{genre}}</genre>
      <author>
         <first-name>{{first_name}}</first-name>
	 <last-name>{{last_name}}</last-name>
      </author>
      <book-title>{{title}}</book-title>
      <annotation>
      {{annotation}}
      </annotation>
      <date></date>
      <coverpage></coverpage>
      <lang>{{lang}}</lang>
   </title-info>
   <document-info>
      <author><email></email></author>
      <date></date>
      <id>{{id}}</id>
      <version>1.1</version>
   </document-info>
   </description>
   <body>
   <title>
      <p>{{first_name}} {{last_name}}</p>
      <p>{{title}}</p>
   </title>
   <section>\n
]]
-- FB2 tale
local END = [[
   </section>
   </body>
   <binary></binary>
</FictionBook>
]]

local fb2 = {}

-- collect strings
fb2.acc = {}
function fb2.add(str) fb2.acc[#fb2.acc+1] = str end

-- title format
function fb2.addtitle(tbl)
   fb2.add("\n  <empty-line/><title><p>")
   fb2.add(fb2.strip(tbl[1]))
   fb2.add("</p></title><empty-line/>\n\n")   
end

-- paragraph format
function fb2.addparagraph(tbl)
   for i = 1, #tbl do
      fb2.add("    <p>")
      fb2.add(tbl[i])
      fb2.add("</p>\n")
   end
end

-- section flag
fb2.setsecion = false

-- section format
function fb2.addsection(tbl)
   if fb2.setsecion then fb2.add("  </section>") else fb2.setsecion = true end
   fb2.add("\n  <empty-line/><title><p>")
   fb2.add(fb2.strip(tbl[1]))
   fb2.add("</p></title>\n  <section>\n")   
end

-- line classification
function fb2.addline(tbl)
   local pref, str = string.match(tbl[1], '^([%p]*)(.-)$')
   fb2.lineprocess[pref] {str}
end

-- transform book description into Lua table
function fb2.getinfo()   
   local f = io.open(INFO)   
   local t = assert(load("return " .. f:read("*a")))
   f:close()
   fb2.info = t()
   -- update ID
   fb2.info.id = "LUA" .. os.date("%Y%m%d%H%M%S")
   -- line processing
   fb2.lineprocess = {}
   fb2.lineprocess[fb2.info.line.section] = fb2.addsection
   fb2.lineprocess[fb2.info.line.title] = fb2.addtitle
   fb2.lineprocess[fb2.info.line.paragraph] = fb2.addparagraph
end

-- remove empty characters
function fb2.strip(str)
   return str:match("^%s*(.*)%s*$")
end

-- main
function fb2.convert()
   if not arg[1] then 
      print("Usage: fb2 file")
      return
   end
   -- read description
   fb2.getinfo()
   -- update fb2 head according to description
   fb2.add(HEAD:gsub('{{(.-)}}', fb2.info))

   local tbl = {}       -- accumulator
   for line in io.lines(arg[1]) do
      local src = tostring(line)
      if src:find('[^%s%c]') then
         -- add nonempty line
         tbl[#tbl+1] = src
      else
         -- check if it is title of paragraph
         if #tbl > 1 then 
	    fb2.addparagraph(tbl)
	 elseif #tbl == 1 then
	    --fb2.addtitle(tbl)
	    fb2.addline(tbl)
	 end
	 tbl = {}
      end
   end
   -- rest of the file
   if #tbl > 1 then fb2.addparagraph(tbl) end
   -- close section
   if fb2.setsecion then fb2.add("  </section>") end
   -- finish structure
   fb2.add(END)
   -- save result
   local f = io.open(arg[1] .. '.fb2', 'w')
   f:write(table.concat(fb2.acc))
   f:close()
   print('File ' .. arg[1] .. '.fb2 is created')
end

-- run
fb2.convert()

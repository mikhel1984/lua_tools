## fb2 


Simple transformation from plain text to fiction book format. The only feature it provides is producing a valid fb2 file.

Usage:
* Prepare book description. Book title, author name and other information is represented as a Lua table in file __info.lua__. 
* Prepare text file. Single text line between two blank lines is assumed as title, but it can be corrected by the line preffixes 
  (preffixes are punctuation characters and can be changed in __info.lua__). Multiline text is a paragraph. After that copy text 
  file into directory with this program. 
* Convert file. Open terminal and write command 
    
     lua fb2.lua your_file_name

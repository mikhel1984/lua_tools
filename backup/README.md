## Small version control system

The program allows to save local changes in a file, restore previous revisions and looking for the difference. 

Main commands:
* ./backup.lua _file_ add [msg] -- save new changes in file
* ./backup.lua _file_ rev [n]   -- convert file into its n-th revision 
* ./backup.lua _file_ diff [n]  -- compare current file with some revision
* ./backup.lua _file_ log   -- show all "commits"

File _diff.lua_ can be used independently.

# t2t

Print **Lua** table in tree-like form. The result can be saved into file.

## Methods 

- _setUnicode()_ - use unicode characters
- _setAscii()_ - use ASCII characters
- _print(tbl,name,iter,file)_ - general form of call with explicit funcitons for the node name, iterator and output file (optional)
- _printList(tbl,file)_ - use predefined funcitons to print lists
- _printMap(tbl,file)_ - use predefined functions to print "arbitrary" lua table

## Example 1 
Table with specific structure. 
```lua
local test = {  -- tree graph
   {
      {{name='bb'},{name='lk'}; name='sd'},
      {{name='te'},{name='on'; {name='st'}}; name='gb'},
      {name='fe'};
      name='we'
   };
   name='tr'
}
-- show 
t2t.print(
  test,
  -- name
  function (t) return t.name end,
  -- iterator
  function (t)
    local i = 0
    return function() i=i+1; return t[i] end
  end
)
```
**Output**
```
tr───we─┬─sd─┬─bb
        │    └─lk
        ├─gb─┬─te
        │    └─on───st
        └─fe
```
## Example 2
List of lists.
```lua
local test = {
 'a', 'b', {'d','e',{'f'}}, 'c',
}
-- show (same as 'printList')
t2t.print(
  test,
  -- name
  function (t)
    return type(t) == 'table' and '{}' or tostring(t)
  end,
  -- iterator
  function (t)
    local i = 0
    if type(t) == 'table' then
      return function ()
        i = i + 1
        return t[i]
      end
    else
      return function () return nil end
    end
  end
)
```
**Output**
```
{}─┬─a
   ├─b
   ├─{}─┬─d
   │    ├─e
   │    └─{}───f
   └─c
```
### Example 3
Key - value pairs.
```lua
local test = {
  a = 1, b = 2, 
  c = {d = 4, e = {f = 5}},
}
-- highlight internal tables
local marker = {}
-- show (same as 'printMap')
T.print(test,
  -- name
  function (t)
    if getmetatable(t) == marker then
      return type(t[2]) == 'table' and t[1]..'={}'
                                    or t[1]..'='..tostring(t[2])
    else
      return '{}'
    end
  end,
  -- iterator
  function (t)
    local k, v
    -- extract value
    if getmetatable(t) == marker then
      t = (type(t[2]) == 'table') and t[2] or {}
    end
    -- iterate
    return function ()
      k, v = next(t,k)
      return k and setmetatable({k,v}, marker)
    end
  end
)
```
**Output**
```
{}─┬─b=2
   ├─a=1
   └─c={}─┬─d=4
          └─e={}───f=5
```

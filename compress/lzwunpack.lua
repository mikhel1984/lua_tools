#!/usr/local/bin/lua
--[[      lzwunpack.lua

Lempel–Ziv–Welch algorithm implementation.
File decompress.

Usage:
  ./lzwunpack.lua file_name

2024, Stanislav Mikhel]]

-- read name from command line
local fname = assert(arg[1], 'file name is expected')
-- expected 'lzwl' extension
local out_name = assert(string.match(fname, '^(.+)%.lzwl$'), 'wrong file type')
local file = assert(io.open(fname, 'rb'), 'file not found')

-- init dict
local dict = {}
for i = 0, 255 do dict[i] = string.char(i) end

-- decompress
local bs, up = 1, 256-1
local fmt = ">I"..tostring(bs)
local w, decompressed = '', {}
local n = file:read(bs)
while n do
  local c = string.unpack(fmt, n)
  if c == up then
    -- update size
    bs, up = bs+1, (up+1)*256-1
    fmt = ">I"..tostring(bs)
    n = file:read(bs)
    c = string.unpack(fmt, n)
  end
  local entry = dict[c] or w..string.sub(w, 1, 1)
  decompressed[#decompressed+1] = entry
  if #w > 0 then
    dict[#dict+1] = w..string.sub(entry, 1, 1)
  end
  w = entry
  -- next
  n = file:read(bs)
end
file:close()

-- save result
local out_file = assert(io.open(out_name, 'w'))
for i = 1, #decompressed do
  out_file:write(decompressed[i])
end
out_file:close()

#!/usr/local/bin/lua
--[[      lzwpack.lua

Lempel–Ziv–Welch algorithm implementation.
File compress.

Usage:
  ./lzwpack.lua file_name

2024, Stanislav Mikhel]]

-- read name from command line
local fname = assert(arg[1], 'file name is expected')
local file = assert(io.open(fname, 'r'), 'file not found')

-- init dict
local dict = {}
for i = 0, 255 do dict[string.char(i)] = i end
local d_next = 256

-- compress
local w, compressed = '', {}
local s = file:read(1)
while s do
  local w_s = w..s
  if dict[w_s] then
    w = w_s
  else
    compressed[#compressed+1] = dict[w]
    dict[w_s] = d_next
    d_next = d_next + 1
    w = s
  end
  -- next
  s = file:read(1)
end
compressed[#compressed+1] = dict[w]
file:close()

-- save result
local out_file = assert(io.open(fname..'.lzwl', 'wb'))
local bs, up = 2, 256*256-1
local fmt = ">I"..tostring(bs)
for _, v in ipairs(compressed) do
  if v >= up then
    -- update size
    out_file:write(string.pack(fmt, up))  -- set marker
    bs, up = bs+1, (up+1)*256-1
    fmt = ">I"..tostring(bs)
  end
  out_file:write(string.pack(fmt, v))
end
out_file:close()

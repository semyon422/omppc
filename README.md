# omppc
osu!mania performance points (and starrate) calculator  
luajit required (for bit operations)
```
Usage: luajit omppc.lua [OPTIONS]

  -b    set path to .osu file  
  -m    set mods in AABB..ZZ format (e.g. EZNFFL) or number  
  -s    set score  
  -v    set verbose mode  
  -j    set json mode  

Examples: 
  luajit omppc.lua -b /path/to/file.osu -s 1000000
  omppc.lua -b /path/to/file.osu -s 1000000
  omppc.lua -b "/path with spaces/to/file.osu" -s 1000000
  omppc.lua -b /path/to/file.osu -s 500000 -m EZDT -v
  omppc.lua -b map.osu -s 500000 -m 64 -j
```

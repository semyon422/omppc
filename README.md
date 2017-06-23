# omppc
osu!mania performance points (and starrate) calculator  

```
Usage: lua omppc.lua [OPTIONS]

  -b, --beatmap              set path to .osu file  
  -m, --mods                 set mods in AABB..ZZ format (e.g. EZNFFL)  
  -s, --score                set score  
  -a, --accuracy             set accuracy  
  -v, --verbose              set verbose mode  
  -d, --debug                set debug mode (more verbose)  

Examples: 
  lua omppc.lua -b /path/to/file.osu -s 1000000 -a 100 -v
  lua omppc.lua --beatmap /path/to/file.osu --score 500000 --accuracy 100 --mods EZDT --debug
```

local omppc = require("omppc")

local file = io.open("beatmap.osu", "r")

local playData = omppc.PlayData:new()
playData.modsData = "DT"
playData.beatmapString = file:read("*all")
playData.score = 855970
playData:process()

file:close()

local data = playData:getData()

print(data.pp)
assert(math.floor(data.pp) == 1095)
print("test complete")

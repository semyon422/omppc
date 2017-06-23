require("tweaks.tweaks")
require("Mods")
require("Note")
require("Beatmap")
require("PerformanceCalculator")
require("PlayData")

input = {}

for i = 1, #arg do
	local cArg = arg[i]
	local nArg = arg[i + 1]
	
	if cArg:sub(1, 2) == "--" then
		local key = cArg:sub(3, -1)
		if key == "beatmap" then
			input.beatmapPath = nArg
		elseif key == "mods" then
			input.mods = nArg
		elseif key == "score" then
			input.score = tonumber(nArg)
		elseif key == "accuracy" then
			input.accuracy = tonumber(nArg) / 100
		elseif key == "verbose" then
			input.verbose = true
		end
		
		i = i + 1
	end
end

playData = PlayData:new()
playData.mods = Mods:new():parse(input.mods)

playData.beatmap = Beatmap:new()
playData.beatmap:parse(input.beatmapPath)
playData.beatmap.mods = playData.mods

playData.starRate = input.starRate
playData.noteCount = input.noteCount
playData.overallDifficulty = input.overallDifficulty

playData.score = input.score
playData.accuracy = input.accuracy

if input.verbose then
	print("Beatmap info:")
	print(" starRate  " .. playData.beatmap:getStarRate())
	print(" noteCount " .. playData.beatmap.noteCount)
	print(" OD        " .. playData.beatmap.overallDifficulty)
	print("Play info")
	print(" score     " .. input.score)
	print(" accuracy  " .. input.accuracy * 100)
	print(" PP        " .. playData:getPerformancePoints())
else
	print(playData:getPerformancePoints())
end
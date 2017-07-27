require("tweaks.tweaks")
require("Mods")
require("Note")
require("Beatmap")
require("OsuManiaPerformanceCalculator")
require("PlayData")

input = {}

for i = 1, #arg do
	local cArg = arg[i]
	local nArg = arg[i + 1]
	
	if cArg:sub(1, 1) == "-" then
		local key
		if cArg:sub(2, 2) == "-" then
			key = cArg:sub(3, -1)
		else
			key = cArg:sub(2, -1)
		end
		
		if key == "beatmap" or key == "b" then
			input.beatmapPath = nArg
		elseif key == "mods" or key == "m" then
			input.mods = nArg
		elseif key == "score" or key == "s" then
			input.score = tonumber(nArg)
		elseif key == "accuracy" or key == "a" then
			input.accuracy = tonumber(nArg) / 100
		elseif key == "verbose" or key == "v" then
			input.verbose = true
		elseif key == "debug" or key == "d" then
			input.debug = true
		end
		
		i = i + 1
	end
end

playData = PlayData:new()
playData.mods = Mods:new():parse(input.mods)

playData.beatmap = Beatmap:new()
playData.beatmap:parse(input.beatmapPath)
playData.beatmap.mods = playData.mods

playData.score = input.score
playData.accuracy = input.accuracy

performanceCalculatorName = "OsuManiaPerformanceCalculator"
playData.PerformanceCalculator = OsuManiaPerformanceCalculator

if input.verbose then
	print("Beatmap info:")
	print(" starRate  " .. playData.beatmap:getStarRate())
	print(" noteCount " .. playData.beatmap.noteCount)
	print(" OD        " .. playData.beatmap:getOverallDifficulty())
	print(" HP        " .. playData.beatmap:getHealthPoints())
	print("Play info")
	print(" mods      " .. playData.mods.modsString)
	print(" score     " .. input.score)
	print(" accuracy  " .. input.accuracy * 100)
	print(" PP        " .. playData:getPerformancePoints())
	print("Performance calculator info:")
	print(" used:     " .. performanceCalculatorName)
elseif input.debug then
	playData:computePerformancePoints()
	print("Mods info")
	print(" modsString   " .. playData.mods.modsString)
	print(" scoreMult    " .. playData.mods.scoreMultiplier)
	print(" timeRate     " .. playData.mods.timeRate)
	print(" odMult       " .. playData.mods.overallDifficultyMultiplier)
	print("Beatmap info:")
	print(" starRate     " .. playData.beatmap:getStarRate())
	print(" noteCount    " .. playData.beatmap.noteCount)
	print(" scaled OD    " .. playData.beatmap:getOverallDifficulty())
	print(" real OD      " .. playData.beatmap.overallDifficulty)
	print(" scaled HP    " .. playData.beatmap:getHealthPoints())
	print(" real HP      " .. playData.beatmap.healthPoints)
	print("Play info")
	print(" scaled score " .. input.score)
	print(" real score   " .. playData.pCalc.realScore)
	print(" accuracy     " .. input.accuracy * 100)
	print(" strainValue  " .. playData.pCalc.strainValue)
	print(" accValue     " .. playData.pCalc.accValue)
	print(" PP           " .. playData:getPerformancePoints())
else
	print(playData:getPerformancePoints())
end
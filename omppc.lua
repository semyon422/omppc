
Class = {}

Class.new = function(self, object)
	local object = object or {}
	
	setmetatable(object, self)
	self.__index = self
	
	return object
end

Mods = Class:new()

Mods.parse = function(self, modsString)
	if not modsString then
		modsString = ""
	end
	self.modsString = modsString
	
	self.scoreMultiplier = 1
	self.timeRate = 1
	self.overallDifficultyMultiplier = 1
	if modsString:find("EZ") then
		self.Easy = true
		self.scoreMultiplier = self.scoreMultiplier * 0.5
		self.overallDifficultyMultiplier = 0.5
	end
	if modsString:find("NF") then
		self.NoFail = true
		self.scoreMultiplier = self.scoreMultiplier * 0.5
	end
	if modsString:find("HT") then
		self.HalfTime = true
		self.scoreMultiplier = self.scoreMultiplier * 0.5
		self.timeRate = 3/4
	end
	if modsString:find("DT") then
		self.DoubleTime = true
		self.timeRate = 3/2
	end
	
	return self
end

Note = Class:new()

Note.parse = function(self, line)
	local x, startTime = line:match("^(%d-),%d-,(%d-),")
	local endTime = line:match(",(%d-):.+:.+:.+:.+:")
	
	self.x = tonumber(x)
	
	local interval = 512 / self.beatmap.keymode
	for newKey = 1, self.beatmap.keymode do
		if self.x >= interval * (newKey - 1) and self.x < newKey * interval then
			self.key = newKey
			break
		end
	end
	
	self.startTime = tonumber(startTime)
	self.endTime = tonumber(endTime) or self.startTime
	
	return self
end

Note.INDIVIDUAL_DECAY_BASE = 0.125
Note.OVERALL_DECAY_BASE = 0.30

Note.overallStrain = 1

Note.init = function(self)
	self.heldUntil = {}
	self.individualStrains = {}
	
	for i = 1, self.beatmap.keymode do
		self.individualStrains[i] = 0
		self.heldUntil[i] = 0
	end
end

Note.getIndividualStrain = function(self)
	return self.individualStrains[self.key]
end

Note.setIndividualStrain = function(self, value)
	self.individualStrains[self.key] = value
end

Note.calculateStrains = function(self, pNote, timeRate)
	local addition = 1
	local timeElapsed = (self.startTime - pNote.startTime) / timeRate
	local individualDecay = math.pow(self.INDIVIDUAL_DECAY_BASE, timeElapsed / 1000)
	local overallDecay = math.pow(self.OVERALL_DECAY_BASE, timeElapsed / 1000)
	
	local holdFactor = 1
	local holdAddition = 0
	
	for i = 1, self.beatmap.keymode do
		self.heldUntil[i] = pNote.heldUntil[i]

		if self.startTime < self.heldUntil[i] and self.endTime > self.heldUntil[i] then
			holdAddition = 1
		end

		if self.endTime == self.heldUntil[i] then
			holdAddition = 0
		end

		if self.heldUntil[i] > self.endTime then
			holdFactor = 1.25
		end
	end
	self.heldUntil[self.key] = self.endTime
	
	for i = 1, self.beatmap.keymode do
		self.individualStrains[i] = pNote.individualStrains[i] * individualDecay
	end
	self:setIndividualStrain(self:getIndividualStrain() + 2 * holdFactor)

	self.overallStrain = pNote.overallStrain * overallDecay + (addition + holdAddition) * holdFactor
end

Beatmap = Class:new()

Beatmap.parse = function(self, filePath)
	local file = io.open(filePath, "r")
    self.noteData = {}

    local blockName = ""
    for line in file:lines() do
        if line:sub(1,1) == "[" then
            blockName = line:match("^%[(.*)%]")
        elseif (blockName == "General" or blockName == "Difficulty") and not line:match("^%s*$") then
			if line:match("^Mode:") then
				self.mode = tonumber(line:match(":(%d+)$"))
			elseif line:match("^OverallDifficulty") then
				self.overallDifficulty = tonumber(line:match(":(%d+)$"))
			elseif line:match("^HPDrainRate") then
				self.healthPoints = tonumber(line:match(":(%d+)$"))
            elseif line:match("^CircleSize") then
				self.keymode = tonumber(line:match(":(%d+)$"))
            end
        elseif blockName == "HitObjects" and not line:match("^%s*$") then
			local note = Note:new({beatmap = self})
			note:parse(line)
			note:init()
            table.insert(self.noteData, note)
        end
    end
	table.sort(self.noteData, function(a, b) return a.startTime < b.startTime end)
	
	self.noteCount = #self.noteData
	file:close()
	
	return self
end

Beatmap.getMaximumScore = function(self)
	return 1000000 * self.mods.scoreMultiplier
end

Beatmap.getOverallDifficulty = function(self)
	return self.overallDifficulty * self.mods.overallDifficultyMultiplier
end

Beatmap.getHealthPoints = function(self)
	return self.healthPoints * self.mods.overallDifficultyMultiplier
end

Beatmap.STAR_SCALING_FACTOR = 0.018

Beatmap.calculateStarRate = function(self)
	self:calculateStrainValues()
	self.starRate = self:calculateDifficulty() * self.STAR_SCALING_FACTOR
end

Beatmap.getStarRate = function(self)
	return self.starRate or self:calculateStarRate() or self.starRate
end

Beatmap.calculateStrainValues = function(self)
	local cNote = self.noteData[1]
	local nNote
	
	for i = 2, #self.noteData do
		nNote = self.noteData[i]
		nNote:calculateStrains(cNote, self.mods.timeRate)
		cNote = nNote
	end
end

Beatmap.STRAIN_STEP = 400
Beatmap.DECAY_WEIGHT = 0.9

Beatmap.calculateDifficulty = function(self)
	local actualStrainStep = self.STRAIN_STEP * self.mods.timeRate

	local highestStrains = {}
	local intervalEndTime = actualStrainStep
	local maximumStrain = 0

	local previousNote
	for _, note in ipairs(self.noteData) do
		while (note.startTime > intervalEndTime) do
			table.insert(highestStrains, maximumStrain)
			if not previousNote then
				maximumStrain = 0
			else
				local individualDecay = math.pow(note.INDIVIDUAL_DECAY_BASE, (intervalEndTime - previousNote.startTime) / 1000)
				local overallDecay = math.pow(note.OVERALL_DECAY_BASE, (intervalEndTime - previousNote.startTime) / 1000)
				maximumStrain = previousNote:getIndividualStrain() * individualDecay + previousNote.overallStrain * overallDecay
			end

			intervalEndTime = intervalEndTime + actualStrainStep
		end

		local strain = note:getIndividualStrain() + note.overallStrain
		if strain > maximumStrain then
			maximumStrain = strain
		end

		previousNote = note
	end

	local difficulty = 0
	local weight = 1
	table.sort(highestStrains, function(a, b) return a > b end)

	for _, strain in ipairs(highestStrains) do
		difficulty = difficulty + weight * strain
		weight = weight * self.DECAY_WEIGHT
	end

	return difficulty
end

OsuManiaPerformanceCalculator = Class:new()

OsuManiaPerformanceCalculator.shouldGivePP = function(self)
	if self.mods.DoubleTime then
		return self.score >= self.beatmap:getMaximumScore() / 2
	else
		return true
	end
end

OsuManiaPerformanceCalculator.computeTotalValue = function(self)
	if not self:shouldGivePP() then
		self.totalValue = 0
		return
	end

	local multiplier = 1.1
	if self.mods.NoFail then
		multiplier = multiplier * 0.90
	end
	if self.mods.SpunOut then
		multiplier = multiplier * 0.95
	end
	if self.mods.Easy then
		multiplier = multiplier * 0.50
	end
	
	self:computeStrainValue()
	self:computeAccValue()

	self.totalValue = math.pow(math.pow(self.strainValue, 1.1) + math.pow(self.accValue, 1.1), 1 / 1.1) * multiplier
end

OsuManiaPerformanceCalculator.computeStrainValue = function(self)
	if self.mods.scoreMultiplier <= 0 then
		self.strainValue = 0
		return
	end

	self.realScore = self.score * (1 / self.mods.scoreMultiplier)
	local score = self.realScore

	self.strainValue = (((5 * math.max(1, self.starRate / 0.0825) - 4) ^ 3) / 110000) * (1 + 0.1 * math.min(1, self.noteCount / 1500))

	if score <= 500000 then
		self.strainValue = self.strainValue * ((score / 500000) * 0.1)
	elseif score <= 600000 then
		self.strainValue = self.strainValue * (0.1 + (score - 500000) / 100000 * 0.2)
	elseif score <= 700000 then
		self.strainValue = self.strainValue * (0.3 + (score - 600000) / 100000 * 0.35)
	elseif score <= 800000 then
		self.strainValue = self.strainValue * (0.65 + (score - 700000) / 100000 * 0.20)
	elseif score <= 900000 then
		self.strainValue = self.strainValue * (0.85 + (score - 800000) / 100000 * 0.1)
	else
		self.strainValue = self.strainValue * (0.95 + (score - 900000) / 100000 * 0.05)
	end
end

OsuManiaPerformanceCalculator.computeAccValue = function(self)
	local hitWindow300 = 34 + 3 * (math.min(10, math.max(0, 10 - self.overallDifficulty)))
	if hitWindow300 <= 0 then
		self.accValue = 0
		return
	end
	
	self.accValue = math.pow((150 / hitWindow300) * math.pow(self.accuracy, 16), 1.8) * 2.5 * (math.min(1.15, math.pow(self.noteCount / 1500, 0.3)))
end

PlayData = Class:new()

PlayData.computePerformancePoints = function(self)
	self.beatmap.mods = self.mods
	self.pCalc = OsuManiaPerformanceCalculator:new({
		beatmap = self.beatmap,
		starRate = self.beatmap:getStarRate(),
		noteCount = self.beatmap.noteCount,
		overallDifficulty = self.beatmap:getOverallDifficulty(),
		
		score = self.score,
		accuracy = self.accuracy,
		mods = self.mods
	})
	self.pCalc:computeTotalValue()
	self.performancePoints = self.pCalc.totalValue
end

PlayData.getPerformancePoints = function(self)
	return self.performancePoints or self:computePerformancePoints() or self.performancePoints
end

if arg then
	input = {}

	for i = 1, #arg do
		local cArg = arg[i]
		local nArg = arg[i + 1]
		
		if cArg:match("^%-") then
			local key
			if cArg:match("^%-%-") then
				key = cArg:match("^%-%-(.*)$")
			else
				key = cArg:match("^%-(.*)$")
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

	if input.verbose then
		playData:computePerformancePoints()
		print(
			([[
Mods info
 modsString   %8s
 scoreMult    %8.2f
 timeRate     %8.2f
 odMult       %8.2f
Beatmap info:
 starRate     %8.2f
 noteCount    %8d
 scaled OD    %8.1f
 real OD      %8.1f
 scaled HP    %8.1f
 real HP      %8.1f
Play info
 scaled score %8d
 real score   %8d
 accuracy     %8.2f
 strainValue  %8.2f
 accValue     %8.2f
 PP           %8.2f
]]
			):format(	
				playData.mods.modsString,
				playData.mods.scoreMultiplier,
				playData.mods.timeRate,
				playData.mods.overallDifficultyMultiplier,
				playData.beatmap:getStarRate(),
				playData.beatmap.noteCount,
				playData.beatmap:getOverallDifficulty(),
				playData.beatmap.overallDifficulty,
				playData.beatmap:getHealthPoints(),
				playData.beatmap.healthPoints,
				input.score,
				playData.pCalc.realScore,
				input.accuracy * 100,
				playData.pCalc.strainValue,
				playData.pCalc.accValue,
				playData:getPerformancePoints()
			)
		)
	else
		print(playData:getPerformancePoints())
	end
end
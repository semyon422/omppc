local Class = {}

Class.new = function(self, object)
	local object = object or {}
	
	setmetatable(object, self)
	self.__index = self
	
	return object
end

local Mods = Class:new()

Mods.scoreRate = 1
Mods.timeRate = 1
Mods.odRate = 1

Mods.parse = function(self, mods)
	self.modsData = mods
	if not mods then
		return
	elseif tonumber(mods) then
		return self:parseNumber(tonumber(mods))
	else
		return self:parseString(mods)
	end
end

Mods.parseString = function(self, modsString)
	if modsString:find("EZ") then
		self.Easy = true
		self.scoreRate = self.scoreRate * 0.5
		self.odRate = 0.5
	end
	if modsString:find("NF") then
		self.NoFail = true
		self.scoreRate = self.scoreRate * 0.5
	end
	if modsString:find("HT") then
		self.HalfTime = true
		self.scoreRate = self.scoreRate * 0.5
		self.timeRate = 3/4
	end
	if modsString:find("DT") then
		self.DoubleTime = true
		self.timeRate = 3/2
	end
	
	return self
end

Mods.parseNumber = function(self, modsNumber)
	if bit.band(modsNumber, 2) == 2 then
		self.Easy = true
		self.scoreRate = self.scoreRate * 0.5
		self.odRate = 0.5
	end
	if bit.band(modsNumber, 1) == 1 then
		self.NoFail = true
		self.scoreRate = self.scoreRate * 0.5
	end
	if bit.band(modsNumber, 256) == 256 then
		self.HalfTime = true
		self.scoreRate = self.scoreRate * 0.5
		self.timeRate = 3/4
	end
	if bit.band(modsNumber, 64) == 64 then
		self.DoubleTime = true
		self.timeRate = 3/2
	end
	
	return self
end

local Note = Class:new()

Note.parse = function(self, line, keymode)
	local x, startTime = line:match("^(%d-),%d-,(%d-),")
	local endTime = line:match(",(%d-):.+:.+:.+:.+:")
	
	self.key = math.ceil(x / 512 * keymode)
	self.keymode = keymode
	
	self.startTime = tonumber(startTime)
	self.endTime = tonumber(endTime) or self.startTime
	
	self.heldUntil = {}
	self.individualStrains = {}
	
	for i = 1, keymode do
		self.individualStrains[i] = 0
		self.heldUntil[i] = 0
	end
	
	return self
end

Note.INDIVIDUAL_DECAY_BASE = 0.125
Note.OVERALL_DECAY_BASE = 0.30

Note.overallStrain = 1

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
	
	for i = 1, self.keymode do
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
	
	for i = 1, self.keymode do
		self.individualStrains[i] = pNote.individualStrains[i] * individualDecay
	end
	self:setIndividualStrain(self:getIndividualStrain() + 2 * holdFactor)
	
	self.overallStrain = pNote.overallStrain * overallDecay + (addition + holdAddition) * holdFactor
end

local Beatmap = Class:new()

Beatmap.parse = function(self, beatmapString)
    self.noteData = {}
	
    local blockName
	for line in string.gmatch(beatmapString .. "\n", "(.-)\n") do
		line = line:match("^%s*(.-)%s*$")
        if line:find("^%[") then
            blockName = line:match("^%[(.*)%]")
        elseif blockName == "General" or blockName == "Difficulty" then
			if line:match("^Mode:") then
				self.mode = tonumber(line:match(":(%d+)$"))
			elseif line:match("^OverallDifficulty") then
				self.od = tonumber(line:match(":(.+)$"))
            elseif line:match("^CircleSize") then
				self.keymode = tonumber(line:match(":(.+)$"))
            end
        elseif blockName == "HitObjects" and not line:match("^%s*$") then
            self.noteData[#self.noteData + 1] = Note:new():parse(line, self.keymode)
        end
    end
	table.sort(self.noteData, function(a, b) return a.startTime < b.startTime end)
	self.noteCount = #self.noteData
	
	self:calculateStarRate()
	
	return self
end

Beatmap.getOD = function(self)
	return self.od * self.mods.odRate
end

Beatmap.STAR_SCALING_FACTOR = 0.018

Beatmap.calculateStarRate = function(self)
	self:calculateStrainValues()
	self.starRate = self:calculateDifficulty() * self.STAR_SCALING_FACTOR
end

Beatmap.getStarRate = function(self)
	return self.starRate
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
	
	local pNote
	for _, note in ipairs(self.noteData) do
		while (note.startTime > intervalEndTime) do
			table.insert(highestStrains, maximumStrain)
			if not pNote then
				maximumStrain = 0
			else
				local individualDecay = math.pow(note.INDIVIDUAL_DECAY_BASE, (intervalEndTime - pNote.startTime) / 1000)
				local overallDecay = math.pow(note.OVERALL_DECAY_BASE, (intervalEndTime - pNote.startTime) / 1000)
				maximumStrain = pNote:getIndividualStrain() * individualDecay + pNote.overallStrain * overallDecay
			end
			
			intervalEndTime = intervalEndTime + actualStrainStep
		end
		
		local strain = note:getIndividualStrain() + note.overallStrain
		if strain > maximumStrain then
			maximumStrain = strain
		end
		
		pNote = note
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

local Calculator = Class:new()

Calculator.computeTotalValue = function(self)
	local multiplier = 0.8
	
	if self.mods.NoFail then
		multiplier = multiplier * 0.90
	end
	if self.mods.Easy then
		multiplier = multiplier * 0.50
	end
	
	self:computeStrainValue()
	self:computeAccValue()
	
	self.totalValue = math.pow(math.pow(self.strainValue, 1.1) + math.pow(self.accValue, 1.1), 1 / 1.1) * multiplier
end

Calculator.computeStrainValue = function(self)
	if self.mods.scoreRate <= 0 then
		self.strainValue = 0
		return
	end
	
	self.realScore = self.score * (1 / self.mods.scoreRate)
	local score = self.realScore
	
	self.strainValue = math.pow(5 * math.max(1, self.beatmap:getStarRate() / 0.2) - 4, 2.2) / 135
	self.strainValue = self.strainValue * (1 + 0.1 * math.min(1, self.beatmap.noteCount / 1500))
	
	if score <= 500000 then
		self.strainValue = 0
	elseif score <= 600000 then
		self.strainValue = self.strainValue * ((score - 500000) / 100000 * 0.3)
	elseif score <= 700000 then
		self.strainValue = self.strainValue * (0.3 + (score - 600000) / 100000 * 0.25)
	elseif score <= 800000 then
		self.strainValue = self.strainValue * (0.55 + (score - 700000) / 100000 * 0.20)
	elseif score <= 900000 then
		self.strainValue = self.strainValue * (0.75 + (score - 800000) / 100000 * 0.15)
	else
		self.strainValue = self.strainValue * (0.9 + (score - 900000) / 100000 * 0.1)
	end
end

Calculator.computeAccValue = function(self)
	local hitWindow300 = 34 + 3 * (math.min(10, math.max(0, 10 - self.beatmap.od)))
	if hitWindow300 <= 0 then
		self.accValue = 0
		return
	end
	
	self.accValue = math.max(0, 0.2 - ((hitWindow300 - 34) * 0.006667)) * self.strainValue * math.pow((math.max(0, self.realScore - 960000) / 40000), 1.1)
end

local PlayData = Class:new()

PlayData.process = function(self)
	self.mods = Mods:new():parse(self.modsData)
	
	self.beatmap = Beatmap:new()
	self.beatmap.mods = self.mods
	self.beatmap:parse(self.beatmapString)
	
	self.calculator = Calculator:new({
		beatmap = self.beatmap,
		score = self.score,
		mods = self.mods
	})
	self.calculator:computeTotalValue()
end

PlayData.getData = function(self)
	return {
		modsData = self.mods.modsData,
		scoreRate = self.mods.scoreRate,
		timeRate = self.mods.timeRate,
		odRate = self.mods.odRate,
		starRate = self.beatmap.starRate,
		noteCount = self.beatmap.noteCount,
		scaledOD = self.beatmap:getOD(),
		od = self.beatmap.od,
		score = self.score,
		realScore = self.calculator.realScore,
		strainValue = self.calculator.strainValue,
		accValue = self.calculator.accValue,
		pp = self.calculator.totalValue
	}
end

PlayData.getJSON = function(self)
	local data = self:getData()
	
	local out = {}
	out[1] = "{"
	for key, value in pairs(data) do
		out[#out + 1] = "\"" .. key .. "\":"
		if type(value) == "number" then
			out[#out + 1] = value .. ","
		elseif type(value) == "string" then
			out[#out + 1] = "\"" .. value .. "\","
		end
	end
	out[#out] = out[#out]:sub(1, -2)
	out[#out + 1] = "}"
	
	return table.concat(out)
end

if arg and arg[0] and arg[0]:find("omppc%.lua$") then
	input = {}
	
	for i = 1, #arg do
		local cArg = arg[i]
		local nArg = arg[i + 1]
		
		if cArg:match("^%-") then
			local key = cArg:match("^%-(.*)$")
			
			if key == "b" then
				input.path = nArg
			elseif key == "m" then
				input.mods = nArg
			elseif key == "s" then
				input.score = tonumber(nArg)
			elseif key == "v" then
				input.verbose = true
			elseif key == "j" then
				input.json = true
			end
			
			i = i + 2
		end
	end
	
	local file = io.open(input.path, "r")
	
	local playData = PlayData:new()
	playData.modsData = input.mods
	playData.beatmapString = file:read("*a")
	playData.score = input.score
	playData:process()
	
	file:close()
	
	local data = playData:getData()
	
	if input.verbose then
		print(
			([[
Mods info
  mods         %8s
  scoreRate    %8.2f
  timeRate     %8.2f
  odRate       %8.2f
Beatmap info:
  starRate     %8.2f
  noteCount    %8d
  scaled OD    %8.1f
  real OD      %8.1f
Play info
  scaled score %8d
  real score   %8d
  strainValue  %8.2f
  accValue     %8.2f
  PP           %8.2f
]]
			):format(
				data.modsData,
				data.scoreRate,
				data.timeRate,
				data.odRate,
				data.starRate,
				data.noteCount,
				data.scaledOD,
				data.od,
				data.score,
				data.realScore,
				data.strainValue,
				data.accValue,
				data.pp
			)
		)
	elseif input.json then
		print(playData:getJSON())
	else
		print(data.pp)
	end
	
	return
end

return {
	Class = Class,
	Mods = Mods,
	Note = Note,
	PlayData = PlayData,
	Beatmap = Beatmap,
	Calculator = Calculator
}
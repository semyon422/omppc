Beatmap = createClass()

Beatmap.parse = function(self, filePath)
	local file = io.open(filePath, "r")
    self.noteData = {}

    local blockName = ""
    for line in file:lines() do
        if line:sub(1,1) == "[" then
            blockName = line:trim():sub(2, -2)
        elseif (blockName == "General" or blockName == "Difficulty") and line:trim() ~= "" then
			if line:startsWith("Mode") then
				self.mode = tonumber(line:trim():sub(6, -1))
			elseif line:startsWith("OverallDifficulty") then
				self.overallDifficulty = tonumber(line:trim():sub(19, -1))
			elseif line:startsWith("HPDrainRate") then
				self.healthPoints = tonumber(line:trim():sub(13, -1))
            elseif line:startsWith("CircleSize") then
				self.keymode = tonumber(line:trim():sub(12, -1))
            end
        elseif blockName == "HitObjects" and line:trim() ~= "" then
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
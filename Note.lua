Note = createClass()

Note.parse = function(self, line)
	local breaked = line:split(",")
	local addition = breaked[6]:split(":")
	
	self.x = tonumber(breaked[1])
	self.y = tonumber(breaked[2])
	
	local interval = 512 / self.beatmap.keymode
	for newKey = 1, self.beatmap.keymode do
		if self.x >= interval * (newKey - 1) and self.x < newKey * interval then
			self.key = newKey
			break
		end
	end
	
	self.startTime = tonumber(breaked[3])
	self.endTime = self.startTime
	self.type = tonumber(breaked[4])
	
	if self.type == 128 then
		self.endTime = tonumber(addition[1])
	end
	
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

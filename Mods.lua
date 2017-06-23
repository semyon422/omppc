Mods = createClass()

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
OsuManiaPerformanceCalculator = createClass()

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

OsuManiaPerformanceCalculator.shouldGivePP = function(self)
	if self.mods.DoubleTime then
		return self.score >= self.beatmap:getMaximumScore() / 2
	else
		return true
	end
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

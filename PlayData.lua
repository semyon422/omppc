PlayData = createClass()

PlayData.computePerformancePoints = function(self)
	self.beatmap.mods = self.mods
	local pCalc = PerformanceCalculator:new({
		starRate = self.beatmap:getStarRate(),
		noteCount = self.beatmap.noteCount,
		overallDifficulty = self.beatmap.overallDifficulty,
		
		score = self.score,
		accuracy = self.accuracy,
		mods = self.mods
	})
	pCalc:computeTotalValue()
	self.performancePoints = pCalc.totalValue
end

PlayData.getPerformancePoints = function(self)
	return self.performancePoints or self:computePerformancePoints() or self.performancePoints
end
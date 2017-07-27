PlayData = createClass()

PlayData.computePerformancePoints = function(self)
	self.beatmap.mods = self.mods
	self.pCalc = self.PerformanceCalculator:new({
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
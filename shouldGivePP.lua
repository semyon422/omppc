OsuManiaPerformanceCalculator.shouldGivePP = function(self)
	if self.mods.DoubleTime then
		return self.score >= self.beatmap:getMaximumScore() / 2
	else
		return true
	end
end
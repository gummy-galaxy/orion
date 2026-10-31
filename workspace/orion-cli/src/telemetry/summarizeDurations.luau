export type Summary = {
	count: number,
	p50: number,
	p95: number,
	max: number,
}

-- The nearest-rank percentile of samples already sorted ascending.
local function percentile(sorted: { number }, fraction: number): number
	return sorted[math.max(1, math.ceil(fraction * #sorted))]
end

-- Summarizes durations in milliseconds as their median, 95th percentile, and
-- slowest, rounded to a hundredth. Returns nil for no samples.
local function summarizeDurations(samples: { number }): Summary?
	if #samples == 0 then
		return nil
	end

	local sorted = table.clone(samples)
	table.sort(sorted)

	local function round(value: number): number
		return math.round(value * 100) / 100
	end

	return {
		count = #sorted,
		p50 = round(percentile(sorted, 0.5)),
		p95 = round(percentile(sorted, 0.95)),
		max = round(sorted[#sorted]),
	}
end

return summarizeDurations

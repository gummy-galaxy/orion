local graphTypes = require("@root/canvas/types")

type Derived = graphTypes.Derived
type Progress = graphTypes.Progress

-- Counts the work anywhere inside a group, leaving out notes and deferred work,
-- which is set aside and doesn't hold a group short of done. Components are
-- counted on their own.
local function countProgress(derived: Derived, groupId: string): Progress
	local stats = derived.groups[groupId]
	return if stats
		then { total = stats.total, done = stats.done, ready = stats.ready, components = stats.components }
		else { total = 0, done = 0, ready = 0, components = 0 }
end

return countProgress

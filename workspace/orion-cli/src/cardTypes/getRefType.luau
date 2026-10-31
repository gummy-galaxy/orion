local getStringField = require("@root/getStringField")
local types = require("@root/types")

type Ref = types.Ref

-- The type a ref attaches to its card. Its adapter records one when it reads
-- the source; refs recorded before types existed are read by their kind.
local function getRefType(ref: Ref): string?
	local recorded = getStringField((ref :: any).type)

	if recorded then
		return recorded
	elseif ref.kind == "pull" then
		return "pr"
	elseif ref.kind == "branch" then
		return "step"
	elseif ref.kind == "issue" then
		-- GitHub keys end in #number, and an issue there expects a pull
		-- request. Other trackers' issues are steps.
		return if ref.key:match("#%d+$") then "placeholder" else "step"
	end

	return nil
end

return getRefType

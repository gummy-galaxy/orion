local types = require("@root/types")

type Ref = types.Ref

-- The type a ref attaches to its card. Its adapter records one when it makes
-- the ref; a ref without one, such as one written by hand, is read by its kind.
local function getRefCardType(ref: Ref): string?
	if ref.type then
		return ref.type
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

return getRefCardType

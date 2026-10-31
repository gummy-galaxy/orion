local types = require("@root/types")

type Doc = types.Doc

local function createEmptyDoc(): Doc
	return {
		version = 3,
		revision = 0,
		settings = { sources = {}, checkSnoozes = {} },
		nodes = {},
		links = {},
		placements = {},
	}
end

return createEmptyDoc

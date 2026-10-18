local types = require("@root/types")

type Doc = types.Doc

local function createEmptyDoc(): Doc
	return {
		version = 2,
		revision = 0,
		settings = { sources = {} },
		nodes = {},
		links = {},
	}
end

return createEmptyDoc

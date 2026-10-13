local getAdapter = require("@root/adapters/getAdapter")
local types = require("@root/types")

type Source = types.Source

local ID = "^[a-z][a-z0-9%-]*$"

local function createSource(kind: string, options: { [string]: { string } }): Source
	local source = getAdapter(kind).createSource(options)
	assert(source.id:match(ID), "source id must use lowercase letters, digits, and hyphens")
	assert(source.id ~= "branch", `source id "branch" is reserved for --ref branch:owner/name@branch`)
	return source
end

return createSource

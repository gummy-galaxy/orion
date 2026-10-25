local json = require("@std/json")

local types = require("@root/types")

type Doc = types.Doc

-- Records what GitHub said a repository is called now in the canvas's directory, by its id, with the host in front on
-- GitHub Enterprise as in ref ids.
local function setRepository(doc: Doc, host: string?, id: string, name: string, checkedAt: string)
	local prefix = if host and host:lower() ~= "github.com" then `{host:lower()}/` else ""
	local repositories = doc.repositories or json.object({})
	repositories[`{prefix}{id}`] = json.object({ name = name, checkedAt = checkedAt })
	doc.repositories = repositories
end

return setRepository

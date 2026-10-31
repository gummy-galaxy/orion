local findRef = require("@root/canvas/refs/findRef")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

local function findBranch(doc: Doc, repo: string, branch: string): Item?
	for _, item in doc.nodes do
		local itemRepo = item.data.repo

		if item.type == "task" and type(itemRepo) == "string" and itemRepo:lower() == repo:lower() then
			local branchRef = findRef(item, "branch")
			local pull = findRef(item, "pull")
			local details = if pull then pull.details else nil

			if (branchRef and branchRef.key:match("@(.+)$") == branch) or (details and details.branch == branch) then
				return item
			end
		end
	end

	return nil
end

return findBranch

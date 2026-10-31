local fs = require("@std/fs")

local listWorktreesAsync = require("@root/sources/hop/listWorktreesAsync")
local types = require("@root/types")

type CommandRunner = types.CommandRunner
type Source = types.Source

-- The main clone of `repo` that hop lists, or nil when hop has none or can't
-- be run.
local function findCloneAsync(_source: Source, run: CommandRunner, command: { string }?, repo: string): string?
	for _, checkout in listWorktreesAsync(run, command) do
		if checkout.primary and checkout.repo:lower() == repo:lower() and fs.exists(checkout.folder) then
			return checkout.folder
		end
	end

	return nil
end

return findCloneAsync

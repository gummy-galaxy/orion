local fs = require("@std/fs")

local listWorktreesAsync = require("@root/sources/hop/listWorktreesAsync")
local types = require("@root/types")

type CommandRunner = types.CommandRunner
type Source = types.Source

--[[
	The worktree hop lists for `branch` of `repo`, or nil when hop has none or
	can't be run. Hop records each worktree's folder, so a card with no session
	yet can still find where its branch is checked out.
]]
local function findCheckoutAsync(
	_source: Source,
	run: CommandRunner,
	command: { string }?,
	repo: string,
	branch: string
): string?
	for _, checkout in listWorktreesAsync(run, command) do
		if checkout.branch == branch and checkout.repo:lower() == repo:lower() and fs.exists(checkout.folder) then
			return checkout.folder
		end
	end

	return nil
end

return findCheckoutAsync

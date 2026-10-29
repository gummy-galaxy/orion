local fs = require("@std/fs")
local json = require("@std/json")

local getCommandJsonAsync = require("@root/adapters/getCommandJsonAsync")
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
	local binary = if command then command[1] else "hop"
	local succeeded, value = pcall(getCommandJsonAsync, run, { binary, "list", "--json" })
	local list = if succeeded then json.asObject(value) else nil

	for _, raw in json.asArray(if list then list.worktrees else nil) or {} do
		local tree = json.asObject(raw)
		local repository = if tree then json.asObject(tree.repository) else nil
		local remote = if repository then repository.remote else nil
		local folder = if tree then tree.path else nil

		if
			tree
			and tree.branch == branch
			and type(remote) == "string"
			and remote:lower() == repo:lower()
			and type(folder) == "string"
			and fs.exists(folder)
		then
			return folder
		end
	end

	return nil
end

return findCheckoutAsync

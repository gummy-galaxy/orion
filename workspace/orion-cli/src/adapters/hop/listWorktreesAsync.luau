local json = require("@std/json")

local getCommandJsonAsync = require("@root/adapters/getCommandJsonAsync")
local hopTypes = require("@root/adapters/hop/types")
local types = require("@root/types")

type CommandRunner = types.CommandRunner
type Checkout = hopTypes.Checkout

--[[
	Every folder hop lists, with its repository and branch, or none when hop
	can't be run. `primary` marks a repository's main clone rather than one of
	its linked worktrees.
]]
local function listWorktreesAsync(run: CommandRunner, command: { string }?): { Checkout }
	local binary = if command then command[1] else "hop"
	local succeeded, value = pcall(getCommandJsonAsync, run, { binary, "list", "--json" })
	local list = if succeeded then json.asObject(value) else nil
	local checkouts: { Checkout } = {}

	for _, raw in json.asArray(if list then list.worktrees else nil) or {} do
		local tree = json.asObject(raw)
		local repository = if tree then json.asObject(tree.repository) else nil
		local remote = if repository then repository.remote else nil
		local folder = if tree then tree.path else nil

		if tree and type(remote) == "string" and type(folder) == "string" then
			table.insert(checkouts, {
				folder = folder,
				repo = remote,
				branch = if type(tree.branch) == "string" then tree.branch else nil,
				primary = tree.primary == true,
			})
		end
	end

	return checkouts
end

return listWorktreesAsync

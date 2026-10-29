local fs = require("@std/fs")

local getAdapter = require("@root/adapters/getAdapter")
local getRefs = require("@root/refs/getRefs")
local types = require("@root/types")

type CommandRunner = types.CommandRunner
type Doc = types.Doc
type Item = types.Item

local function isOnBranchAsync(folder: string, branch: string, run: CommandRunner): boolean
	if not fs.exists(folder) then
		return false
	end

	local succeeded, result = pcall(run, { "git", "-C", folder, "branch", "--show-current" }, nil)
	return succeeded and result.ok and result.stdout:match("^%s*(.-)%s*$") == branch
end

-- The folders the card's sessions ran in, most recent first.
local function getSessionFolders(item: Item): { string }
	type Found = { folder: string, updatedAt: string }
	local found: { Found } = {}

	for _, ref in getRefs(item) do
		local details = ref.details
		local folder = if ref.kind == "session" and details then details.cwd else nil

		if type(folder) == "string" then
			table.insert(found, { folder = folder, updatedAt = ref.updatedAt or "" })
		end
	end

	table.sort(found, function(a: Found, b: Found)
		return a.updatedAt > b.updatedAt
	end)

	local folders: { string } = {}

	for _, entry in found do
		table.insert(folders, entry.folder)
	end

	return folders
end

--[[
	A folder where the card's branch is checked out: the latest folder one of
	its sessions ran in that's still on the branch, or else one a source such
	as hop knows of. Nil when there's none, since guessing would start the
	agent on the wrong work.
]]
local function findStartFolderAsync(
	doc: Doc,
	item: Item,
	repo: string,
	branch: string,
	run: CommandRunner,
	commands: { [string]: { string } }
): string?
	for _, folder in getSessionFolders(item) do
		if isOnBranchAsync(folder, branch, run) then
			return folder
		end
	end

	for _, source in doc.settings.sources do
		local succeeded, adapter = pcall(getAdapter, source.kind)
		local find = if succeeded and adapter.source then adapter.source.findCheckoutAsync else nil
		local folder = if find then find(source, run, commands[source.id], repo, branch) else nil

		if folder then
			return folder
		end
	end

	return nil
end

return findStartFolderAsync

local fs = require("@std/fs")

local adapterTypes = require("@root/sources/types")
local getAdapter = require("@root/sources/getAdapter")
local getRefs = require("@root/canvas/refs/getRefs")
local sessionTypes = require("@root/sources/sessions/types")
local types = require("@root/types")

type CommandRunner = types.CommandRunner
type Doc = types.Doc
type Item = types.Item
type Place = sessionTypes.Place
type Source = types.Source
type SourceVerbs = adapterTypes.SourceVerbs

local function runGitAsync(folder: string, args: { string }, run: CommandRunner): string?
	if not fs.exists(folder) then
		return nil
	end

	local argv = { "git", "-C", folder }
	table.move(args, 1, #args, #argv + 1, argv)
	local succeeded, result = pcall(run, argv, nil)

	return if succeeded and result.ok then result.stdout:match("^%s*(.-)%s*$") else nil
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

-- Session folders of the card and then of the canvas's other cards in `repo`.
local function getRepoSessionFolders(doc: Doc, item: Item, repo: string): { string }
	local folders = getSessionFolders(item)

	for _, node in doc.nodes do
		local nodeRepo = node.data.repo

		if node ~= item and type(nodeRepo) == "string" and nodeRepo:lower() == repo:lower() then
			for _, folder in getSessionFolders(node) do
				table.insert(folders, folder)
			end
		end
	end

	return folders
end

-- Asks each of the canvas's sources that can answer, in order.
local function askSourcesAsync(doc: Doc, ask: (Source, SourceVerbs) -> string?): string?
	for _, source in doc.settings.sources do
		local succeeded, adapter = pcall(getAdapter, source.kind)
		local folder = if succeeded and adapter.source then ask(source, adapter.source) else nil

		if folder then
			return folder
		end
	end

	return nil
end

--[[
	Where a session on the card starts. A folder with the card's branch checked
	out comes first: the latest one its sessions ran in, or one a source such as
	hop knows of. Otherwise it's the repository's main clone, from a source or
	from the folder of any session in the repository, for the agent to make a
	worktree in. With neither, there's no folder.
]]
local function findStartFolderAsync(
	doc: Doc,
	item: Item,
	repo: string?,
	branch: string?,
	run: CommandRunner,
	commands: { [string]: { string } }
): (string?, Place)
	if repo and branch then
		for _, folder in getSessionFolders(item) do
			if runGitAsync(folder, { "branch", "--show-current" }, run) == branch then
				return folder, "checkout"
			end
		end

		local checkout = askSourcesAsync(doc, function(source: Source, verbs: SourceVerbs)
			local find = verbs.findCheckoutAsync
			return if find then find(source, run, commands[source.id], repo, branch) else nil
		end)

		if checkout then
			return checkout, "checkout"
		end
	end

	if repo then
		local clone = askSourcesAsync(doc, function(source: Source, verbs: SourceVerbs)
			local find = verbs.findCloneAsync
			return if find then find(source, run, commands[source.id], repo) else nil
		end)

		if clone then
			return clone, "clone"
		end

		for _, folder in getRepoSessionFolders(doc, item, repo) do
			local common = runGitAsync(folder, { "rev-parse", "--path-format=absolute", "--git-common-dir" }, run)
			local root = if common then common:match("^(.+)[/\\]%.git$") else nil

			if root and fs.exists(root) then
				return root, "clone"
			end
		end
	end

	return nil, "none"
end

return findStartFolderAsync

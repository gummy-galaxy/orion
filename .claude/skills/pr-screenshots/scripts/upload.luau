-- Commits images to the media branch without checking it out and prints a
-- Markdown image link for each one. Run it from inside the repository.
--
--   lute run upload.luau <pr number> <image>...
--
-- Images land in pr-<number>/ on agent/pr-media. Links point at the new commit,
-- so they keep working when the same file name is uploaded again later.

local fs = require("@std/fs")
local process = require("@lute/process")

local README = table.concat({
	"# PR media",
	"",
	"Screenshots for pull request descriptions, one folder per pull request.",
	"Nothing here is merged. Pull requests link to these files by commit.",
	"",
}, "\n")
local ATTEMPTS = 3

local function run(command: { string }, environment: { [string]: string }?): process.ProcessResult
	if not environment then
		return process.run(command)
	end

	local merged = table.clone(process.env)

	for name, value in environment do
		merged[name] = value
	end

	return process.run(command, { env = merged })
end

local function output(command: { string }, environment: { [string]: string }?): string
	local result = run(command, environment)

	if not result.ok then
		error(`{table.concat(command, " ")} failed: {result.stderr}`, 0)
	end

	return (result.stdout:gsub("%s+$", ""))
end

local function basename(filePath: string): string
	return filePath:match("[^/]+$") or filePath
end

local function commitImages(number: string, images: { string }, branch: string, indexPath: string): string?
	local environment = { GIT_INDEX_FILE = indexPath }
	local parent: string? = nil

	if run({ "git", "fetch", "--quiet", "origin", `refs/heads/{branch}` }).ok then
		parent = output({ "git", "rev-parse", "FETCH_HEAD" })
		output({ "git", "read-tree", parent :: string }, environment)
	else
		local readmePath = `{indexPath}.readme`

		fs.writeStringToFile(readmePath, README)

		local readme = output({ "git", "hash-object", "-w", readmePath })

		fs.remove(readmePath)
		output({ "git", "read-tree", "--empty" }, environment)
		output({ "git", "update-index", "--add", "--cacheinfo", `100644,{readme},README.md` }, environment)
	end

	for _, image in images do
		local blob = output({ "git", "hash-object", "-w", image })

		output(
			{ "git", "update-index", "--add", "--cacheinfo", `100644,{blob},pr-{number}/{basename(image)}` },
			environment
		)
	end

	local tree = output({ "git", "write-tree" }, environment)
	local commitCommand = { "git", "commit-tree", tree, "-m", `Add screenshots for #{number}` }

	if parent then
		table.insert(commitCommand, "-p")
		table.insert(commitCommand, parent)
	end

	local commit = output(commitCommand)

	if not run({ "git", "push", "--quiet", "origin", `{commit}:refs/heads/{branch}` }).ok then
		return nil
	end

	return commit
end

local function main()
	local number = process.args[2]
	local images = table.move(process.args, 3, #process.args, 1, {})

	if not number or #images == 0 then
		error("usage: lute run upload.luau <pr number> <image>...", 0)
	end

	local branch = process.env.PR_MEDIA_BRANCH or "agent/pr-media"
	local repository = output({ "gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner" })
	local indexPath = output({ "mktemp" })

	for _ = 1, ATTEMPTS do
		local commit = commitImages(number, images, branch, indexPath)

		if fs.exists(indexPath) then
			fs.remove(indexPath)
		end

		if commit then
			for _, image in images do
				local name = basename(image)
				local label = name:gsub("%.[^.]+$", "")

				print(`![{label}](https://github.com/{repository}/blob/{commit}/pr-{number}/{name}?raw=true)`)
			end

			return
		end
	end

	error(`Could not push to {branch} after {ATTEMPTS} attempts`, 0)
end

main()

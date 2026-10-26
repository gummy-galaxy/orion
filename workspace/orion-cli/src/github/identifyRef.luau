local findRepository = require("@root/github/findRepository")
local getKeyRepo = require("@root/refs/getKeyRepo")
local getMovedUrl = require("@root/github/getMovedUrl")
local types = require("@root/types")

type Doc = types.Doc
type Ref = types.Ref

local GITHUB_KINDS = { pull = true, issue = true, branch = true }

--[[
	Gives a GitHub ref with no id the id of the repository the canvas's
	directory knows by its key's name, current or old, and moves its key and URL
	to the current name, so a ref someone names after a move still matches the
	card that tracks it. Reads only what this machine has recorded. A name the
	directory doesn't know leaves the ref as it is, until a refresh looks it up.
]]
local function identifyRef(doc: Doc, ref: Ref): Ref
	local repo = if GITHUB_KINDS[ref.kind] and not ref.id then getKeyRepo(ref.key) else nil
	local found = if repo then findRepository(doc, repo.location) else nil

	if not repo or not found then
		return ref
	end

	local prefix = if repo.host == "github.com" then "" else `{repo.host}/`
	ref.id = `{found.key}{repo.suffix}`
	ref.key = `{prefix}{found.name}{repo.suffix}`
	ref.url = if ref.url then getMovedUrl(ref.url, `{repo.owner}/{repo.name}`, found.name) else nil

	return ref
end

return identifyRef

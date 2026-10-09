local fetchPulls = require("@root/github/fetchPulls")
local getAuthoredOpen = require("@root/github/getAuthoredOpen")
local getRefFor = require("@root/github/getRefFor")
local githubTypes = require("@root/github/types")
local types = require("@root/types")

type Ref = githubTypes.Ref
type Fetched = githubTypes.Fetched
type Doc = types.Doc
type CommandRunner = types.CommandRunner

local function collectPulls(doc: Doc, run: CommandRunner, discover: boolean): Fetched
	local refs: { Ref } = {}

	for _, item in doc.nodes do
		local ref = getRefFor(item, doc.settings.githubOwner)

		if ref then
			table.insert(refs, ref)
		end
	end

	local authored, viewer = getAuthoredOpen(run)
	return {
		pulls = fetchPulls(run, refs),
		authored = authored,
		viewer = viewer,
		discover = discover,
	}
end

return collectPulls

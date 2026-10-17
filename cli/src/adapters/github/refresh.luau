local adapterTypes = require("@root/adapters/types")
local applyPulls = require("@root/github/applyPulls")
local collectPulls = require("@root/github/collectPulls")
local githubTypes = require("@root/github/types")
local types = require("@root/types")

type Doc = types.Doc
type CommandRunner = types.CommandRunner
type RefreshOptions = adapterTypes.RefreshOptions

local function refresh(doc: Doc, run: CommandRunner, options: RefreshOptions): (Doc) -> githubTypes.Report
	local fetched = collectPulls(doc, run, options.discover)

	return function(current: Doc): githubTypes.Report
		return applyPulls(current, fetched, options.now)
	end
end

return refresh

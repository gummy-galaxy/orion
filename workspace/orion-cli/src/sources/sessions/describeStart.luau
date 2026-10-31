local sessionTypes = require("@root/sources/sessions/types")

type StartOptions = sessionTypes.StartOptions

-- One line on where a session would start, for orion session presets and
-- orion session start.
local function describeStart(options: StartOptions): string
	local line = if options.place == "checkout"
		then `Starts {options.agent} in {options.folder}.`
		elseif
			options.place == "clone"
		then `Starts {options.agent} in {options.folder} to make a worktree for {options.branch or "a new branch"}.`
		else `Starts {options.agent} with no folder, so it asks for one.`

	if not options.attaches then
		line ..= ` Add a {options.agent} source with orion source add {options.source.kind} to see the session on the card.`
	end

	return line
end

return describeStart

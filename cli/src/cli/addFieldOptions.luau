local cli = require("@batteries/cli")

-- Item fields, which cards take. Groups take their own, set with group set.
local function addFieldOptions(parser: cli.Parser)
	parser:add("status", "option", { help = "todo, active, review, blocked, deferred, or done" })
	parser:add("repo", "option", { help = "Repository it belongs to, as owner/name (empty to clear)" })
	parser:add("who", "option", { help = "Whose move: you, review, or ci (empty to clear)" })
	parser:add("note", "option", { help = "Free-form note (empty to clear)" })
	parser:add("shape", "option", {
		help = "How a component is drawn: service, store, actor, external, interface, process, or queue (empty to clear)",
	})
	parser:add("color", "option", {
		help = "A component's tint: teal, blue, purple, amber, rose, green, or slate (empty to clear)",
	})
	parser:add("kind", "option", {
		help = "step; gate for one that's done once everything it waits on is; or component for a part of a system, not work",
	})
end

return addFieldOptions

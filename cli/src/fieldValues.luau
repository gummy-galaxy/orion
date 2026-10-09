-- The values item fields accept, in the order help text and MCP schemas list them.
return table.freeze({
	statuses = table.freeze({ "todo", "active", "review", "blocked", "deferred", "done" }),
	who = table.freeze({ "you", "review", "ci" }),
	kinds = table.freeze({ "step", "gate" }),
	arrangements = table.freeze({ "auto", "custom" }),
})

-- The values item fields accept, in the order help text and MCP schemas list them.
return table.freeze({
	statuses = table.freeze({ "todo", "active", "review", "blocked", "deferred", "done" }),
	who = table.freeze({ "you", "review", "ci" }),
	kinds = table.freeze({ "step", "gate", "component" }),
	arrangements = table.freeze({ "auto", "custom" }),
	-- How a component is drawn: the default box, a data store, a person or agent, a service outside the system,
	-- a user interface, a job or command, or a stream of events.
	shapes = table.freeze({ "service", "store", "actor", "external", "interface", "process", "queue" }),
	-- Tints for groups and components. Components take their nearest group's tint unless they set their own.
	colors = table.freeze({ "teal", "blue", "purple", "amber", "rose", "green", "slate" }),
})

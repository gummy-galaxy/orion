return table.freeze({
	-- Clients that register and unregister support, in the order they run.
	names = table.freeze({ "codex", "claude", "cursor" }),
	-- What a registered client runs after the orion binary.
	serveArguments = table.freeze({ "mcp", "serve" }),
})

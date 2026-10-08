-- JSON-RPC error codes and the MCP protocol versions the server speaks, newest first.
return table.freeze({
	serverVersion = "0.1.0",
	versions = table.freeze({ "2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05" }),
	errors = table.freeze({
		parse = -32700,
		invalidRequest = -32600,
		methodNotFound = -32601,
		invalidParams = -32602,
	}),
})

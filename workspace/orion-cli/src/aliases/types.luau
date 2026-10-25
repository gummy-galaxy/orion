-- A renamed command or option that keeps working under its old name until the next release prunes it.
export type Alias = {
	-- A command alias renames a command path, and the MCP tools under it with it. An option alias renames one
	-- command's long option, and the matching MCP tool argument.
	kind: "command" | "option",
	-- The old name: a command path such as "card create", or an option without its dashes such as "file".
	from: string,
	-- The current name, in the same form.
	to: string,
	-- For an option, the path of the command that takes it, under the command's current name.
	command: string?,
	-- The day the alias was added, as YYYY-MM-DD.
	added: string,
	-- The pull request that added it.
	pr: number,
}

return nil

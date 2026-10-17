local test = require("@std/test")

local cli = require("@root/cli")
local describeCommands = require("@root/cli/describeCommands")
local mcpTypes = require("@root/cli/mcp/types")
local tools = require("@root/cli/mcp/tools")

type Argument = describeCommands.Argument
type CommandDescription = describeCommands.CommandDescription
type Tool = mcpTypes.Tool

-- CLI commands MCP deliberately leaves out, each with the reason. Their options aren't checked.
local COMMAND_EXCEPTIONS: { [string]: string } = {
	["canvas current"] = "orion_canvases already reports the active canvas",
	["canvas path"] = "reports the local data folder, which tools have no use for",
	["server start"] = "runs the long-lived app server, which belongs in a terminal",
	["source add github"] = "configures a source with adapter-specific settings, so setup stays in the CLI",
	["source add jira"] = "configures a source with adapter-specific settings, so setup stays in the CLI",
	["source add hop"] = "configures a source with adapter-specific settings, so setup stays in the CLI",
	["source remove"] = "changes which sources ingest reads, so it stays with source add",
	["mcp start"] = "is the MCP server itself",
	["help"] = "prints help text, which MCP clients already get from tools/list",
}

-- Single options MCP leaves out, keyed by the command and the option.
local OPTION_EXCEPTIONS: { [string]: string } = {
	["card import --stdin"] = "reads refs from stdin, which a tool call can't pipe; orion_import takes them as a list",
}

-- Tool fields that aren't CLI options, keyed by the tool and the field. view picks the command orion_inspect runs.
local FIELD_EXCEPTIONS: { [string]: string } = {
	["orion_inspect view"] = "picks which command the tool runs",
}

-- The canvas option is shared by every command, so tools take it through the same workspace field.
local SHARED_FIELD = "canvas"

-- Collects the commands with no subcommands, keyed by their path such as "card list".
local function collectLeaves(command: CommandDescription, leaves: { [string]: CommandDescription })
	if #command.commands == 0 then
		local path = (command.name:gsub("^orion ?", ""))
		leaves[path] = command
		return
	end

	for _, child in command.commands do
		collectLeaves(child, leaves)
	end
end

local function getLeaves(): { [string]: CommandDescription }
	local leaves: { [string]: CommandDescription } = {}
	collectLeaves(cli.describe(), leaves)
	return leaves
end

-- The command paths a tool can run. Tools that choose between commands list each one.
local function getToolPaths(tool: Tool): { string }
	local paths: { string } = {}

	for _, command in tool.commands or { tool.command } do
		if #command > 0 then
			table.insert(paths, table.concat(command, " "))
		end
	end

	return paths
end

local function hasArgument(command: CommandDescription, name: string): boolean
	for _, argument in command.arguments do
		if argument.name == name then
			return true
		end
	end

	return false
end

-- Maps each command path to the tools that run it.
local function getCoverage(): { [string]: { Tool } }
	local coverage: { [string]: { Tool } } = {}

	for _, tool in tools do
		for _, path in getToolPaths(tool) do
			coverage[path] = coverage[path] or {}
			table.insert(coverage[path], tool)
		end
	end

	return coverage
end

-- An option is exposed when one of the tools that runs its command has a field for it. The json option is exposed
-- by a tool that sets json, which appends --json to the command it runs.
local function isOptionExposed(path: string, argument: Argument, coverage: { [string]: { Tool } }): boolean
	for _, tool in coverage[path] or {} do
		if argument.name == "json" then
			if tool.json then
				return true
			end
		else
			for _, field in tool.fields do
				if (field.flag or field.name) == argument.name then
					return true
				end
			end
		end
	end

	return false
end

test.case("every CLI command is exposed through an MCP tool or deliberately left out", function(assert)
	local leaves = getLeaves()
	local coverage = getCoverage()
	local missing: { string } = {}

	for path in leaves do
		if not COMMAND_EXCEPTIONS[path] and not coverage[path] then
			table.insert(missing, `orion {path} has no MCP tool`)
		end
	end

	for path in COMMAND_EXCEPTIONS do
		if not leaves[path] then
			table.insert(missing, `COMMAND_EXCEPTIONS lists orion {path}, which the CLI no longer has`)
		end
	end

	table.sort(missing)
	assert.eq(table.concat(missing, "\n"), "", "CLI commands without an MCP tool")
end)

test.case("every CLI option is exposed through an MCP tool or deliberately left out", function(assert)
	local leaves = getLeaves()
	local coverage = getCoverage()
	local missing: { string } = {}

	for path, leaf in leaves do
		if COMMAND_EXCEPTIONS[path] then
			continue
		end

		for _, argument in leaf.arguments do
			local key = `{path} --{argument.name}`

			if not isOptionExposed(path, argument, coverage) and not OPTION_EXCEPTIONS[key] then
				table.insert(missing, `orion {key} has no MCP field`)
			end
		end
	end

	for key in OPTION_EXCEPTIONS do
		local path, name = key:match("^(.-) %-%-(.+)$")
		local leaf = if path then leaves[path] else nil

		if not (leaf and hasArgument(leaf, name :: string)) then
			table.insert(missing, `OPTION_EXCEPTIONS lists orion {key}, which the CLI no longer has`)
		end
	end

	table.sort(missing)
	assert.eq(table.concat(missing, "\n"), "", "CLI options without an MCP field")
end)

test.case("every MCP tool and field maps onto a CLI command and option", function(assert)
	local leaves = getLeaves()
	local problems: { string } = {}

	for _, tool in tools do
		local paths = getToolPaths(tool)

		for _, path in paths do
			local leaf = leaves[path]

			if not leaf then
				table.insert(problems, `{tool.name} runs orion {path}, which the CLI doesn't have`)
				continue
			end

			if tool.json and not hasArgument(leaf, "json") then
				table.insert(problems, `{tool.name} sets json, but orion {path} has no --json`)
			end
		end

		for _, field in tool.fields do
			local name = field.flag or field.name

			if name == SHARED_FIELD or FIELD_EXCEPTIONS[`{tool.name} {field.name}`] then
				continue
			end

			local found = false

			for _, path in paths do
				local leaf = leaves[path]

				if leaf and hasArgument(leaf, name) then
					found = true
				end
			end

			if not found then
				table.insert(problems, `{tool.name} field {field.name} maps to no option of the commands it runs`)
			end
		end
	end

	table.sort(problems)
	assert.eq(table.concat(problems, "\n"), "", "MCP tools that don't match the CLI")
end)

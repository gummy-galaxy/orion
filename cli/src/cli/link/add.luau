local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local getRequired = require("@root/cli/getRequired")
local graph = require("@root/graph")
local requestedRevision = require("@root/cli/requestedRevision")
local resolveId = require("@root/query/resolveId")
local runEdit = require("@root/cli/runEdit")
local types = require("@root/types")

type Context = context.Context
type Doc = types.Doc
type Link = types.Link

local function writeJson(
	options: Context,
	doc: Doc,
	ids: { string },
	linked: { Link },
	kind: string,
	dryRun: boolean,
	baseRevision: number
)
	local items: json.Array = {}
	local links: json.Array = {}

	for _, id in ids do
		table.insert(items, json.object({ id = id, label = graph.label(graph.get(doc, id)) }))
	end

	for index = 1, #ids - 1 do
		local object = json.object({ from = ids[index], to = ids[index + 1], kind = kind })
		object.label = linked[index].label
		table.insert(links, object)
	end

	options.write(json.serialize(
		json.object({
			action = "link",
			dryRun = dryRun,
			baseRevision = baseRevision,
			revision = doc.revision,
			items = items,
			links = links,
		}),
		true
	))
end

-- One link reads as a sentence about the pair it joins.
local function describeLink(doc: Doc, from: string, to: string, link: Link, kind: string): string
	local label = link.label
	local suffix = if label then ` ("{label}")` else ""
	local isWork = graph.isWork(graph.get(doc, from)) and graph.isWork(graph.get(doc, to))
	local sentence = if kind ~= "blocks"
		then `{from} and {to} are related`
		elseif isWork then `{to} now waits on {from}`
		else `{from} → {to}`

	return `{sentence}{suffix}`
end

local function describeChain(
	doc: Doc,
	ids: { string },
	linked: { Link },
	kind: string,
	dryRun: boolean,
	baseRevision: number
): string
	local count = #ids - 1
	local revision = if dryRun then `{baseRevision}` else `{baseRevision} → {doc.revision}`
	local lines = {
		`{if dryRun then "Would link" else "Linked"} {count} {if count == 1 then "pair" else "pairs"} at revision {revision}`,
	}

	for index = 1, count do
		local label = linked[index].label
		table.insert(lines, `  {ids[index]} → {ids[index + 1]} ({kind}){if label then ` "{label}"` else ""}`)
	end

	return table.concat(lines, "\n")
end

return table.freeze({
	help = "Link each adjacent pair of items",
	define = function(parser: cli.Parser)
		parser:add("from", "positional", { help = "The item that has to happen first" })
		parser:add("to", "positional", { help = "The item that waits on it" })
		parser:add("next", "variadic", { help = "Further items in the chain" })
		parser:add("related", "flag", { help = "Link without blocking" })
		parser:add("label", "option", { help = "What the link carries, such as HTTP (empty to clear)" })
		parser:add("dry-run", "flag", { help = "Preview changes and current revision without writing" })
		parser:add("if-revision", "option", { help = "Write only if the document has this revision" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local from, to = getRequired(parser, "from"), getRequired(parser, "to")
		local kind = if parser:has("related") then "related" else "blocks"
		local ids = { from, to }

		for _, id in parser:variadics() do
			table.insert(ids, id)
		end

		local dryRun = parser:has("dry-run")
		local linked: { Link } = {}
		local doc, baseRevision = runEdit(options.dir, dryRun, requestedRevision(parser), function(current)
			for index, input in ids do
				ids[index] = resolveId(current, input)
			end

			for index = 1, #ids - 1 do
				linked[index] = graph.link(current, ids[index], ids[index + 1], kind, parser:get("label"))
			end
		end)
		from, to = ids[1], ids[2]

		if options.asJson then
			writeJson(options, doc, ids, linked, kind, dryRun, baseRevision)
		elseif #ids == 2 and not dryRun then
			options.write(describeLink(doc, from, to, linked[1], kind))
		else
			options.write(describeChain(doc, ids, linked, kind, dryRun, baseRevision))
		end
	end,
})

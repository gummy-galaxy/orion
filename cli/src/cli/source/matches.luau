local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local findItem = require("@root/graph/findItem")
local getLabel = require("@root/graph/getLabel")
local loadDoc = require("@root/store/loadDoc")

type Context = context.Context

return table.freeze({
	help = "List unplaced pull requests and the cards they likely belong to",
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(_parser: cli.Parser, options: Context)
		local doc = loadDoc(options.dir)
		local unplaced = if doc.github then json.asArray(doc.github.unplaced) else nil
		local values: json.Array = unplaced or {}

		if options.asJson then
			options.write(json.serialize(values, true))
		else
			local lines: { string } = {}

			for _, raw in values do
				local pull = json.asObject(raw)

				if not pull then
					continue
				end

				table.insert(lines, `{pull.repo}#{pull.number}  {pull.title}`)

				for _, entry in json.asArray(pull.matches) or {} do
					local candidate = json.asObject(entry)

					if candidate then
						local item = if type(candidate.id) == "string" then findItem(doc, candidate.id) else nil
						table.insert(
							lines,
							`  {candidate.id}  {if item then getLabel(item) else ""}  {candidate.score}`
						)
					end
				end
			end

			options.write(if #lines > 0 then table.concat(lines, "\n") else "No unplaced pull requests.")
		end
	end,
})

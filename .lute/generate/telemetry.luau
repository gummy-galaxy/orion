--[[
	Writes `docs/public/reference/telemetry.json` from the CLI's telemetry event
	catalog, in the shape the telemetry backend validates batches against: each
	event's name mapped to its properties' types. The docs site serves it next
	to the event list. Run it after changing
	`workspace/orion-cli/src/telemetry/events.luau`, commit what it writes, and
	copy it over the backend's `catalog.json`.
]]
local fs = require("@std/fs")
local path = require("@std/path")

local telemetryEvents = require("@workspace/orion-cli/src/telemetry/events")

type Property = telemetryEvents.Property

local INDENT = "  "

local targetDir = path.resolve("docs/public/reference")
local target = path.join(targetDir, "telemetry.json")

-- Written by hand rather than with @std/json, whose key order isn't stable.
-- The spec keeps names to snake_case, so none needs escaping. Objects always
-- break across lines, which Prettier keeps as written.
local function generate(): string
	local names: { string } = {}

	for _, event in telemetryEvents.list do
		table.insert(names, event.name)
	end

	table.sort(names)

	local lines = { "{", `{INDENT}"events": \{` }

	for index, name in names do
		local event = telemetryEvents.byName[name]
		local separator = if index < #names then "," else ""

		if #event.properties == 0 then
			table.insert(lines, `{INDENT:rep(2)}"{name}": \{}{separator}`)
			continue
		end

		table.insert(lines, `{INDENT:rep(2)}"{name}": \{`)
		table.insert(lines, `{INDENT:rep(3)}"properties": \{`)

		local properties: { Property } = table.clone(event.properties)
		table.sort(properties, function(a: Property, b: Property)
			return a.name < b.name
		end)

		for propertyIndex, property in properties do
			local propertySeparator = if propertyIndex < #properties then "," else ""
			table.insert(lines, `{INDENT:rep(4)}"{property.name}": "{property.type}"{propertySeparator}`)
		end

		table.insert(lines, `{INDENT:rep(3)}}`)
		table.insert(lines, `{INDENT:rep(2)}}{separator}`)
	end

	table.insert(lines, `{INDENT}}`)
	table.insert(lines, "}")

	return table.concat(lines, "\n") .. "\n"
end

-- Writes the file, or with `checkOnly` leaves it alone. Returns false when
-- `checkOnly` finds it out of date.
local function generateTelemetry(checkOnly: boolean): boolean
	local contents = generate()
	local current = if fs.exists(target) then fs.readFileToString(target) else nil

	if current == contents then
		print("docs/public/reference/telemetry.json is up to date")
		return true
	end

	if checkOnly then
		print(
			"docs/public/reference/telemetry.json is out of date. "
				.. "Run `lute run generate telemetry` and commit the result."
		)
		return false
	end

	fs.createDirectory(targetDir, { makeParents = true })
	fs.writeStringToFile(target, contents)
	print("Updated docs/public/reference/telemetry.json")

	return true
end

return generateTelemetry

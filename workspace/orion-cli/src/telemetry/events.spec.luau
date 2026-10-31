local test = require("@std/test")

local events = require("@root/telemetry/events")

-- The telemetry backend refuses a catalog that breaks these, so the spec
-- catches it before the export does.
local RESERVED_PROPERTIES = { "build_version", "build_commit", "build_channel", "session_id" }
local PROPERTY_TYPES = { "string", "number", "integer", "boolean" }
local MAX_STRING_LENGTH = 100

local function isIdentifier(text: string): boolean
	return text:match("^[a-z][a-z0-9_]*$") ~= nil
end

test.case("event and property names are unique snake_case", function(assert)
	local seenEvents: { [string]: boolean } = {}

	for _, event in events.list do
		assert.eq(isIdentifier(event.name), true)
		assert.eq(seenEvents[event.name], nil)
		seenEvents[event.name] = true

		local seenProperties: { [string]: boolean } = {}

		for _, property in event.properties do
			assert.eq(isIdentifier(property.name), true)
			assert.eq(seenProperties[property.name], nil)
			seenProperties[property.name] = true
		end
	end
end)

test.case("no event carries a property the backend adds itself", function(assert)
	for _, event in events.list do
		for _, property in event.properties do
			assert.eq(table.find(RESERVED_PROPERTIES, property.name), nil)
		end
	end
end)

test.case("every property has a type the backend checks", function(assert)
	for _, event in events.list do
		for _, property in event.properties do
			assert.neq(table.find(PROPERTY_TYPES, property.type), nil)
		end
	end
end)

test.case("only string properties list values, and each fits the backend", function(assert)
	for _, event in events.list do
		for _, property in event.properties do
			if property.values == nil then
				continue
			end

			assert.eq(property.type, "string")

			for _, value in property.values do
				assert.eq(#value <= MAX_STRING_LENGTH, true)
			end
		end
	end
end)

test.case("every event names a family and who sends it", function(assert)
	local familyNames: { [string]: boolean } = {}

	for _, family in events.families do
		familyNames[family.name] = true
	end

	for _, event in events.list do
		assert.eq(familyNames[event.family], true)
		assert.eq(#event.sources > 0, true)
	end
end)

test.case("byName finds each event", function(assert)
	for _, event in events.list do
		assert.eq(events.byName[event.name], event)
	end
end)

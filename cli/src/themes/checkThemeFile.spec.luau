local json = require("@std/json")
local test = require("@std/test")

local checkThemeFile = require("@root/themes/checkThemeFile")

test.case("reads both schemes and the name, which labels the theme", function(assert)
	local check = checkThemeFile(
		"dusk.json",
		json.serialize(json.object({
			name = "Dusk",
			light = json.object({ ["canvas.background"] = "#fff" }),
			dark = json.object({ ["canvas.background"] = "#000" }),
		}))
	)

	assert.eq(check.error, nil)
	assert.eq(check.label, "Dusk")
	assert.eq(check.schemes, { "light", "dark" })
	assert.eq(check.notes, {})
end)

test.case("labels a file without a name by its file name, and caps long names", function(assert)
	assert.eq(checkThemeFile("night.json", '{"dark":{}}').label, "night")
	assert.eq(checkThemeFile("x.json", '{"name":"   ","dark":{}}').label, "x")
	assert.eq(#checkThemeFile("x.json", '{"name":"' .. string.rep("a", 80) .. '","dark":{}}').label, 40)
end)

test.case("notes tokens it does not name and skips them", function(assert)
	local check = checkThemeFile("x.json", '{"light":{"canvas.background":"#fff","canvas.glow":"#f00"}}')

	assert.eq(check.error, nil)
	assert.eq(check.notes, { "Ignored unknown token canvas.glow in light" })
end)

test.case("refuses files that are not usable, with the reason", function(assert)
	local cases = {
		{ "{nope", "is not valid JSON" },
		{ "[]", "must be a JSON object" },
		{ '{"name":"Empty"}', 'needs a "light" or "dark" object of token values' },
		{ '{"dark":"#000"}', '"dark" must be an object of token values' },
		{ '{"dark":{"canvas.background":3}}', "dark canvas.background must be a string" },
		{
			'{"light":{"canvas.background":"url(https://example.com/a.png)"}}',
			"light canvas.background uses url(), which a color cannot",
		},
	}

	for _, case in cases do
		local check = checkThemeFile("bad.json", case[1])

		assert.eq(check.error, case[2])
		assert.eq(check.schemes, {})
	end
end)

local json = require("@std/json")
local test = require("@std/test")

local encodeStableJson = require("@root/store/encodeStableJson")

test.case("encodeStableJson sorts keys at every depth", function(assert)
	local value = json.object({ zeta = 1, alpha = json.object({ b = true, a = "x" }), list = { 2, json.object({}) } })

	assert.eq(
		encodeStableJson(value),
		'{\n  "alpha": {\n    "a": "x",\n    "b": true\n  },\n  "list": [\n    2,\n    {}\n  ],\n  "zeta": 1\n}\n'
	)
end)

test.case("encodeStableJson writes the same text however a value was built", function(assert)
	local first = json.object({ a = 1 })
	first.b = 2
	local second = json.object({ b = 2 })
	second.a = 1

	assert.eq(encodeStableJson(first), encodeStableJson(second))
	assert.eq(encodeStableJson({}), "[]\n")
	assert.eq(encodeStableJson(json.object({ empty = json.null })), '{\n  "empty": null\n}\n')
end)

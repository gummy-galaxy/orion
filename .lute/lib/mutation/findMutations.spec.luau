local test = require("@std/test")

local findMutations = require("./findMutations")

local function describe(source: string): { string }
	local found = {}

	for _, mutation in findMutations(source) do
		table.insert(found, `{mutation.line}:{mutation.column} {mutation.original} -> {mutation.replacement}`)
	end

	return found
end

test.case("findMutations swaps comparison, arithmetic, and logical operators", function(assert)
	assert.eq(describe("return a == b and c < d or e + f"), {
		"1:10 == -> ~=",
		"1:15 and -> or",
		"1:21 < -> <=",
		"1:25 or -> and",
		"1:30 + -> -",
	})
end)

test.case("findMutations drops not, flips booleans, and raises numbers", function(assert)
	assert.eq(describe("local x = not y\nreturn true, 0, 1.5"), {
		"1:11 not -> ",
		"2:8 true -> false",
		"2:14 0 -> 1",
		"2:17 1.5 -> 2.5",
	})
end)

test.case("findMutations rewrites only the mutated token and keeps the rest of the source", function(assert)
	local source = "-- keep this\nif count >= 2 then\n\treturn not done -- and this\nend\n"
	local mutations = findMutations(source)

	assert.eq(mutations[1].source, "-- keep this\nif count > 2 then\n\treturn not done -- and this\nend\n")
	assert.eq(mutations[2].source, "-- keep this\nif count >= 3 then\n\treturn not done -- and this\nend\n")
	assert.eq(mutations[3].source, "-- keep this\nif count >= 2 then\n\treturn  done -- and this\nend\n")
end)

test.case("findMutations leaves type annotations, strings, and concatenation alone", function(assert)
	assert.eq(describe('local name: "a" | "b" = "x" .. y\ntype Pair = { number }'), {})
end)

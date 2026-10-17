local test = require("@std/test")

local slugify = require("@root/slugify")

test.case("slugify turns text into lowercase hyphenated words", function(assert)
	assert.eq(slugify("Ship it"), "ship-it")
	assert.eq(slugify("  Design / QA!  "), "design-qa")
	assert.eq(slugify("!!!"), "item")
	assert.eq(slugify("!!!", nil, "group"), "group")
end)

test.case("slugify cuts long slugs at the last word boundary that fits", function(assert)
	assert.eq(slugify("Pick the next slider family piece to build"), "pick-the-next-slider-family")
	assert.eq(slugify("Keep card ids stable across renames"), "keep-card-ids-stable-across")
	assert.eq(slugify("Check the hash before the release", 24), "check-the-hash-before")
end)

test.case("slugify keeps a slug that ends at the limit on a word boundary", function(assert)
	local text = "aaaa bbbb cccc dddd eeee ffff gg hhhh"
	assert.eq(slugify(text), "aaaa-bbbb-cccc-dddd-eeee-ffff-gg")
	assert.eq(#slugify(text), 32)
end)

test.case("slugify cuts mid-word only when the first word is too long", function(assert)
	assert.eq(slugify(string.rep("a", 40) .. " b"), string.rep("a", 32))
end)

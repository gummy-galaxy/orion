local test = require("@std/test")

local getEntryFileName = require("@root/store/getEntryFileName")

test.case("getEntryFileName keeps slugs as they are", function(assert)
	assert.eq(getEntryFileName("extract-slider_2"), "extract-slider_2.json")
end)

test.case("getEntryFileName escapes every other byte, uppercase letters included", function(assert)
	assert.eq(getEntryFileName("a>b"), "a%3eb.json")
	assert.eq(getEntryFileName("Card"), "%43ard.json")
	assert.eq(getEntryFileName("../x"), "%2e%2e%2fx.json")
	assert.eq(getEntryFileName("50%"), "50%25.json")
	assert.eq(getEntryFileName(""), "%.json")
end)

test.case("getEntryFileName steers clear of names Windows reserves", function(assert)
	assert.eq(getEntryFileName("con"), "%63on.json")
	assert.eq(getEntryFileName("com1"), "%63om1.json")
	assert.eq(getEntryFileName("lpt9"), "%6cpt9.json")
	assert.eq(getEntryFileName("com"), "com.json")
	assert.eq(getEntryFileName("console"), "console.json")
end)

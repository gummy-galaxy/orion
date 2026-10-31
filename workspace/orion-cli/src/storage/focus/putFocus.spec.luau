local json = require("@std/json")
local test = require("@std/test")

local clearFocus = require("@root/storage/focus/clearFocus")
local putFocus = require("@root/storage/focus/putFocus")
local readFocus = require("@root/storage/focus/readFocus")
local testing = require("@root/testing")

test.case("putFocus records a window's focus and clears it only when that window closes", function(assert)
	local dir = testing.directory("put-focus")
	putFocus(dir, "first", "group", { "a" } :: json.Array)

	local focus = readFocus(dir)
	assert.eq(focus and focus.open, "group")
	assert.eq(focus and focus.selected[1], "a")

	putFocus(dir, "second", nil, nil, true)
	assert.eq(readFocus(dir) ~= nil, true)

	putFocus(dir, "first", nil, nil, true)
	assert.eq(readFocus(dir), nil)
end)

test.case("readFocus is nil once the focus is cleared", function(assert)
	local dir = testing.directory("clear-focus")
	putFocus(dir, "tab", nil, nil)
	clearFocus(dir)
	assert.eq(readFocus(dir), nil)
	clearFocus(dir)
end)

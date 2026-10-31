local test = require("@std/test")

local decodeFocus = require("@root/storage/focus/decodeFocus")

test.case("decodeFocus keeps the open group and only the string ids in the selection", function(assert)
	local focus = decodeFocus([[{"tab":"t","open":"group","selected":["a",3,"b"],"updatedAt":"2026-10-05T00:00:00Z"}]])
	assert.eq(focus.open, "group")
	assert.eq(#focus.selected, 2)
	assert.eq(focus.selected[2], "b")
	assert.eq(focus.updatedAt, "2026-10-05T00:00:00Z")
	assert.eq(decodeFocus([[{"open":null}]]).open, nil)
end)

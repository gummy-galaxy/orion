local json = require("@std/json")
local test = require("@std/test")

local testing = require("@root/testing")

test.case("telemetry on and off record the choice that status reports", function(assert)
	local _root, run = testing.createHarness("telemetry-commands")

	assert.strContains(run({ "telemetry", "status" }), "Nobody on this machine has chosen yet.")
	assert.strContains(run({ "telemetry", "on" }), "Sharing anonymous usage data as install")

	local status =
		json.asObject(json.deserialize(run({ "telemetry", "status", "--json" })) :: json.Value) :: json.Object
	assert.eq(status.choice, "on")
	assert.eq(testing.isRandomId(status.installId), true)

	assert.strContains(run({ "telemetry", "off" }), "Not sharing usage data.")
	assert.strContains(run({ "telemetry", "status" }), "https://oriongraph.app/reference/telemetry")
end)

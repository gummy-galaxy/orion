local test = require("@std/test")

local createSource = require("@root/adapters/jira/createSource")

test.case("Jira adapter validates command and browse URL", function(assert)
	local source = createSource({
		command = { ' ["acli","jira","workitem","search"] ' },
		browse = { "https://jira.example.com/browse/" },
	})
	assert.eq(source.id, "jira")
	assert.eq(source.browse, "https://jira.example.com/browse")
	assert.throws(function()
		createSource({ command = { ' ["acli","jira","workitem","search","--token"] ' } })
	end)
	assert.throws(function()
		createSource({ command = { ' ["acli","jira","workitem","search"] ' }, browse = { "http://jira" } })
	end)
end)

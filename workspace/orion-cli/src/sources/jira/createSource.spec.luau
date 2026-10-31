local test = require("@std/test")

local createSource = require("@root/sources/jira/createSource")

test.case("Jira adapter validates command and browse URL", function(assert)
	local source, command = createSource({
		command = { ' ["acli","jira","workitem","search"] ' },
		browse = { "https://jira.example.com/browse/" },
	})
	assert.eq(source.id, "jira")
	assert.eq(source.browse, "https://jira.example.com/browse")
	assert.eq(command, { "acli", "jira", "workitem", "search" })
	assert.eq((source :: any).command, nil)
	assert.throws(function()
		createSource({ command = { ' ["acli","jira","workitem","search","--token"] ' } })
	end)
	assert.throws(function()
		createSource({ command = { ' ["acli","jira","workitem","search"] ' }, browse = { "http://jira" } })
	end)
end)

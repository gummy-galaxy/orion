local test = require("@std/test")

local joinRepositoryPath = require("@root/storybook/joinRepositoryPath")

test.case("joinRepositoryPath resolves relative parts with forward slashes", function(assert)
	assert.eq(joinRepositoryPath("app/src/components", "../hooks/useRing"), "app/src/hooks/useRing")
	assert.eq(
		joinRepositoryPath("workspace/orion-app", "./src/Ring.stories.tsx"),
		"workspace/orion-app/src/Ring.stories.tsx"
	)
end)

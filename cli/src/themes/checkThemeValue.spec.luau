local test = require("@std/test")

local checkThemeValue = require("@root/themes/checkThemeValue")

test.case("accepts plain CSS for each token group", function(assert)
	local accepted = {
		{ "color", "#fff" },
		{ "color", "#1c1726cc" },
		{ "color", "rebeccapurple" },
		{ "color", "transparent" },
		{ "color", "rgb(10 20 30 / 50%)" },
		{ "color", "color-mix(in srgb, #b4481f 20%, #fff)" },
		{ "color", "var(--edge-hot)" },
		{ "color", "var(--surface)" },
		{ "status", "oklch(70% 0.1 200)" },
		{ "font", "'Schibsted Grotesk', system-ui, sans-serif" },
		{ "weight", "700" },
		{ "size", "13px" },
		{ "size", "0.8rem" },
		{ "line-height", "1.45" },
		{ "line-height", "16px" },
		{ "space", "8px" },
		{ "radius", "0 7px 0 3px" },
		{ "radius", "50%" },
		{ "shadow", "0 1px 2px rgb(0 0 0 / 0.3), 0 5px 16px rgb(0 0 0 / 0.25)" },
		{ "shadow", "inset 0 0 0 2px var(--accent-default)" },
		{ "shadow", "none" },
		{ "duration", "150ms" },
		{ "duration", "0.2s" },
		{ "easing", "ease-out" },
		{ "easing", "cubic-bezier(0.2, 0.9, 0.3, 1.25)" },
	}

	for _, case in accepted do
		assert.eq(checkThemeValue(case[1], case[2]), nil, `{case[1]}: {case[2]}`)
	end
end)

test.case("refuses anything that is not plain CSS for its group", function(assert)
	local refused = {
		{ "color", "url(https://example.com/a.png)" },
		{ "color", 'image-set("a.png" 1x)' },
		{ "color", "expression(alert(1))" },
		{ "color", "light-dark(#fff, #000)" },
		{ "color", "#fff; } body { background: red" },
		{ "color", "#fff) url(https://example.com)" },
		{ "color", "#fff)(" },
		{ "color", "var(--not-a-token)" },
		{ "color", "var(--surface-background, red)" },
		{ "color", '@import "x.css"' },
		{ "color", "red\\7b" },
		{ "color", "" },
		{ "font", "Arial; }" },
		{ "font", "url(font.woff2)" },
		{ "font", "'Schibsted Grotesk" },
		{ "weight", "bold" },
		{ "weight", "1200" },
		{ "size", "13" },
		{ "size", "900px" },
		{ "line-height", "12" },
		{ "line-height", "normal" },
		{ "space", "-4px" },
		{ "radius", "1px 2px 3px 4px 5px" },
		{ "radius", "calc(1px + 2px)" },
		{ "radius", "1px  2px" },
		{ "shadow", "0 1px 2px url(https://example.com/a.png)" },
		{ "shadow", "0 1px 2px #000; } body { color: red" },
		{ "duration", "150" },
		{ "duration", "-150ms" },
		{ "duration", "30s" },
		{ "easing", "steps(4)" },
		{ "easing", "cubic-bezier(0.2, 0.9)" },
		{ "easing", "var(--motion-easing-pop)" },
	}

	for _, case in refused do
		assert.neq(checkThemeValue(case[1], case[2]), nil, `{case[1]}: {case[2]}`)
	end
end)

test.case("names the reason for a refused value", function(assert)
	assert.eq(checkThemeValue("color", "url(https://example.com/a.png)"), "uses url(), which a color cannot")
	assert.eq(checkThemeValue("size", "13"), "must be a length in px, rem, or em")
	assert.eq(checkThemeValue("color", "  "), "is empty")
end)

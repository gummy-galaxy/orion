# Luau style

- Export one function per module, from a file named after it with a verb first, such as `platform/getDataDir.luau`. Put shared types in a sibling `types.luau` and tests in `<function>.spec.luau` beside it. Constant tables, data lists, and command modules stay tables.
- Keep a helper that only one module uses as a local function there. Once a second module needs it, move it into its own module rather than copying it. Look for an existing helper, such as `getStringField`, before writing one.
- Keep related requires, type aliases, constants, and short assignments together. Separate those groups and adjacent functions with blank lines.
- Name a required module after the module itself, such as `local cli = require("@batteries/cli")` and `local io = require("@lute/io")`, without prefixing the package.
- Within functions, use blank lines between logical steps: setup, guards, loops and branches, state changes, and the final result. Keep statements that form one step together.
- Run StyLua after editing Luau, then review the spacing yourself. StyLua sorts requires and formats statements, but does not add these logical blank lines.

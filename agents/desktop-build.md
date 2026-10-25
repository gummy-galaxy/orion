# Trying a desktop build

A fresh worktree has none of the build's dependencies, and the build fails partway without them. Before the first build there, run `npm ci` in `workspace/orion-app/` and `workspace/orion-desktop/`, and `lute pkg install` in `workspace/orion-cli/` for the Luau packages that `prepare-sidecar` requires.

To let someone try a change in the desktop app, run `npm run build` in `workspace/orion-desktop/`, then replace `/Applications/Orion.app`, which installs it for every user on the machine. Every build shares one bundle id, so a fresh build elsewhere goes unseen, and a second copy in `~/Applications` shows up as a duplicate. Quit Orion, move the installed app to the Trash, `ditto` `workspace/orion-desktop/target/release/bundle/macos/Orion.app` into its place, register it with `lsregister -f`, and relaunch. When the icon changed, also `touch` the bundle and run `killall Dock`, which otherwise keeps showing the old icon.

# System diagrams

A canvas can also draw a system: services, apps, files, and outside tools, linked by what flows between them. Make each part a component with `orion card create <name> --shape <shape> [--note <what it does>]`; a shape makes the card a component. Components have no status, never count as work, and grow to show their whole name and note.

- Shapes: `service` (a box, the default), `store` (a cylinder, for files and databases), `actor` (a pill, for people and agents), `external` (a dashed box, for anything outside the system), `interface` (a window, for a UI), `process` (a chevron, for commands and jobs), and `queue` (a stack, for streams of events).
- Colors: set one on a group with `orion group set <group> --color <color>`, and the components and groups inside take it unless they set their own.

Link components with `orion link create <caller> <callee> --label <what travels>`, pointing from what starts a call to what it calls. Group them by boundary, such as an app, a process, or everything outside the system, and nest smaller groups inside for its parts. `orion group create` wraps items that share a parent, so make the inner groups first.

Create the links before the groups, then run `orion group set <group> --arrange auto` on each group so the app lays it out by its links and leaves room for their labels; it lays out inner groups first. Run Tidy in the app for the top level. A folded group lists what it holds, and opening one shows the components outside it that it talks to. A note at the top level that explains the shapes and colors helps first-time readers.

# CLI

The `gg-ui` binary that copies registry items into a consuming Gleam project.
**Deferred** — no implementation work in flight. This doc specifies what
we'll build when we do, so the registry and component layout work in flight
can target a fully-specified consumer.

## Strategy: fork `packages/shadcn`

Don't rewrite from scratch. shadcn's CLI is a few thousand lines of
hard-won edge-case handling around registry resolution, config parsing,
file writing, JSON-schema validation, install detection, MCP, presets, and
template scaffolding. Reusing it gets us 60–70% of the surface for free.

Where to fork from: `packages/shadcn` in
`/Users/andres/code/opensource/shadcn-ui`. Vendor as
`packages/gg_ui_cli/` in the monorepo (see
[`monorepo.md`](monorepo.md)).

## What's reusable as-is

These don't reference TS / React / npm in ways that affect Gleam, just JSON
and filesystem:

| Module in `packages/shadcn/src/`              | Reuse? | Notes |
| --------------------------------------------- | ------ | ----- |
| `registry/api.ts`                             | ✓      | High-level "fetch + resolve" entry point |
| `registry/fetcher.ts`                         | ✓      | HTTP / disk fetch of registry JSON |
| `registry/resolver.ts`                        | ✓      | Topological sort + cycle detection |
| `registry/parser.ts`                          | ✓      | JSON parse + schema validate |
| `registry/validate.ts`                        | ✓      | Item validation |
| `registry/validator.ts`                       | ✓      | Cross-item validation |
| `registry/namespaces.ts`                      | ✓      | `@org/registry` parsing |
| `registry/loader.ts`                          | ✓      | Local-fs loader |
| `registry/search.ts`                          | ✓      | Search index |
| `registry/utils.ts`                           | ✓      | Generic helpers |
| `registry/config.ts`                          | ~      | Reads `components.json` — adapt aliases |
| `registry/env.ts`                             | ✓      | Env-var handling |
| `registry/errors.ts`                          | ✓      | Custom error types |
| `registry/constants.ts`                       | ~      | Reword shadcn-isms |
| `commands/view.ts`                            | ✓      | Print item details |
| `commands/search.ts`                          | ✓      | Search registry |
| `commands/info.ts`                            | ~      | Adapt to print Gleam-flavoured info |
| `commands/build.ts`                           | ✓      | Build a registry from sources |
| `commands/diff.ts`                            | ✓      | Diff installed vs current |
| `commands/docs.ts`                            | ✓      | Per-item docs URLs |
| `commands/mcp.ts`                             | ✓      | MCP server — gives us Claude / Cursor integration free |
| `commands/preset.ts`                          | ✓      | Preset resolution (`base-nova`, etc.) |
| `schema/index.ts`                             | ~      | Add `npmDependencies` field |
| `templates/*.ts`                              | ~      | Replace with Gleam project templates |

## What needs rewriting

| Module                                        | Rewrite                |
| --------------------------------------------- | ---------------------- |
| `commands/init.ts`                            | Writes `gg_ui.toml`-flavoured `components.json`, reads `gleam.toml`, runs `gleam add` instead of `pnpm add`. |
| `commands/add.ts`                             | Resolves Gleam module paths from `aliases`. Runs both `gleam add` (Hex deps) and `pnpm add` (npmDependencies). |
| `commands/apply.ts`                           | Applies a `registry:style` overlay by `@import`ing into the user's CSS — same shape as shadcn's but for our overlay files. |
| `commands/migrate.ts`                         | Delete for v1 (no v0→v1 migrations to run yet). |
| `utils/transformers/transform-icons.ts`       | Rewrite for Gleam syntax — same algorithm, different parser. See [`icons.md`](icons.md). |
| `utils/transformers/transform-imports.ts`     | Rewrite for Gleam `import x/y/z as a` syntax. |
| `utils/transformers/transform-jsx.ts`         | Delete — no JSX. |
| `utils/transformers/transform-rsc.ts`         | Delete — no RSC. |
| `utils/transformers/transform-tailwind.ts`    | Mostly delete — Tailwind v4 doesn't have a JS config. Keep only the CSS-vars writer. |
| `utils/transformers/transform-cva.ts`         | Delete or no-op — our recipes use `gva`, but they're not rewritten on copy. |
| `utils/transformers/transform-legacy-icons.ts`| Delete — no legacy state to migrate from. |
| `utils/get-project-info.ts`                   | Detect Gleam project (look for `gleam.toml`), detect package manager, detect Tailwind setup. |
| `utils/updaters/update-tailwind-*.ts`         | Adapt to v4-only flow. |
| `migrations/*`                                | Delete. |
| `preflights/*`                                | Adapt — check for `gleam.toml`, Tailwind v4, valid `components.json`. |
| `preset/*`                                    | Mostly reusable — preset shape (base+style+theme+icon+font) is identical. |

## Commands

Same surface as shadcn:

```
gg-ui init                  # Interactive setup. Writes components.json,
                            # appends @imports to user's CSS, installs deps.
gg-ui init --preset base-nova-neutral
                            # Non-interactive — pick a preset, accept defaults.

gg-ui add button            # Resolve "button" + its registryDependencies,
                            # write files, rewrite imports & icons, install
                            # Hex + npm deps.
gg-ui add button popover    # Multiple at once.
gg-ui add --all             # Everything in the registry.

gg-ui view button           # Print metadata + file list, no writes.
gg-ui search popover        # Fuzzy-search the registry.
gg-ui diff button           # Show diff between installed and registry source.

gg-ui build                 # For registry authors: validate a registry.json,
                            # resolve dependencies, emit a built registry to
                            # dist/.

gg-ui mcp                   # Start an MCP server exposing the registry to
                            # Claude / Cursor / Zed. Inherits shadcn's
                            # implementation almost verbatim.

gg-ui apply theme-stone     # Apply a registry:theme or :style to the user's
                            # CSS without copying any files.

gg-ui preset list           # Show available presets.
gg-ui preset use base-nova  # Set the active preset in components.json.

gg-ui docs button           # Open the docs URL for an item.
gg-ui info                  # Diagnostic dump of project + config + registry.
```

## Distribution

- npm: `gg-ui` (binary name + package name). Mirror shadcn's distribution
  shape — global install or `npx gg-ui add ...`.
- Optional Homebrew formula later (shadcn doesn't ship one; defer until
  asked).
- The binary runs Node 20+. No Bun-specific deps in the fork.

## File-write rules

When `gg-ui add <item>` writes a registry file to disk:

1. **Default target path** — `aliases.<type>` from `components.json` decides
   the root directory. `registry:ui` → `aliases.ui`, etc. The file's
   basename comes from the registry `path` minus the
   `packages/gg_ui/src/gg_ui/ui/` prefix.
2. **Explicit `target` wins** — if the registry item declares
   `files[].target`, use that path verbatim.
3. **Existing file** — if a file already exists at the target path:
   - Same content → skip silently.
   - Different content → prompt `[O]verwrite / [S]kip / [D]iff` (matches
     shadcn UX).
   - `--yes` flag → overwrite without prompting.
4. **What gets copied** — only the thin `ui/<component>.gleam` files plus
   `helpers/cn` (the `utils` analogue). The **headless layer is never copied**:
   each `ui/` file's `import gg_base_ui/<component>/<component> as base_<x>`
   stays **verbatim**, because `gg_base_ui` is a real Hex dependency (exactly
   like a Base UI import survives a shadcn eject).
5. **Imports get rewritten** before writing — only the *alias-relative* imports
   (`gg_ui/helpers/cn` → the user's `aliases.lib`); the `gg_base_ui` import is
   left untouched. See [`config.md`](config.md) for the rules.
6. **Icons get rewritten** before writing — see [`icons.md`](icons.md).
7. **Deps get installed** after all writes succeed — including
   `gleam add gg_base_ui` so the verbatim headless import resolves.

## Dependency install

Two installers, one CLI call:

```
gg-ui add button
→ gleam add gg_base_ui lustre gva                   (from item.dependencies)
→ pnpm add @floating-ui/dom                         (from item.npmDependencies)
```

`gg_base_ui` is always among the Hex deps — the copied `ui/` file imports it
verbatim, so it must resolve as a real dependency.

Hex installer behavior:

- Read `gleam.toml`, parse `[dependencies]`.
- For each dep in `item.dependencies`, skip if present, otherwise run
  `gleam add <name>` (which writes back to `gleam.toml` and updates the
  manifest).
- Version pinning — shadcn pins to `latest`. We do the same; the user can
  bump in `gleam.toml` after the fact.

npm installer behavior:

- Detect package manager via `get-project-info.ts` (`pnpm-lock.yaml` →
  pnpm, etc.).
- Run the appropriate `add` command.

Both installers can be skipped with `--no-install` (matches shadcn).

## Testing strategy

Inherit shadcn's test approach:

- **Snapshot tests** for transformer outputs. Cheap, catches regressions.
- **Fixture projects** under `packages/gg_ui_cli/test/fixtures/<scenario>/`
  — minimal Gleam projects with various `components.json` configs. Run the
  CLI against each and assert the resulting files.
- **MCP integration tests** — call the MCP server with mock requests,
  assert responses match the registry.

## What ships in v1 (when we get there)

Minimum lovable CLI:

- `init` (interactive + `--preset`)
- `add` (single + multiple items)
- `view`
- `apply` (theme / style overlays)
- `mcp`

Everything else (`search`, `diff`, `build`, `docs`, `info`, `preset`) is
nice-to-have for v1.1.

## Until then

The registry items can be installed by hand:

1. Read `gg_ui_registry/items/<name>.json`.
2. Run `gleam add` for each `dependencies` entry — always including
   `gg_base_ui` (the headless package the copied file imports).
3. Copy each thin `ui/<component>.gleam` (+ `helpers/cn`) into your `src/`.
   Leave the `import gg_base_ui/...` line verbatim; rewrite only the
   alias-relative imports per [`config.md`](config.md). Never copy the
   headless layer.
4. `@import` any `registry:theme` / `registry:style` fragments into your CSS
   entry (the one that imports Tailwind first).

We'll document this manual flow in the consumer README once we have a
first non-trivial consumer (the companies selector). It's the same
mechanical work the CLI will eventually do — just done by a human in the
meantime.

## Why not write the CLI in Gleam

Tempting (everything else is Gleam), but:

- Gleam doesn't have a mature AST manipulation story. The transformer
  pipeline (icons, imports) needs syntactic rewriting at minimum, and
  doing that with regex *can* work but is brittle. TypeScript + simple
  hand-written tokenisers is mature and well-trodden.
- npm distribution is the consumer's expectation. A Gleam-on-BEAM CLI
  ships an Erlang VM with it (heavy). A Gleam-on-JS CLI is just a
  TypeScript CLI with extra steps.
- The shadcn CLI is in TS already — forking is genuinely cheaper than
  re-implementing in Gleam.

This is a pragmatic concession. The CLI is a build-time tool that
operates on the registry data layer — it doesn't need to *be* Gleam.

## Open questions

- **Per-target install knobs.** A future component might be JS-only (uses
  FFI). Should `gleam add` flag the target? Probably handled at
  `gg_ui_registry` level (a `targets: ["javascript"]` field on the item)
  rather than in `gleam.toml`. Defer until we hit it.
- **Telemetry.** shadcn collects opt-in usage stats. We probably don't,
  initially. Easy to add later.
- **Registry-build CI.** When we publish a new registry version, what
  validates it? `gg-ui build` + JSON-schema check in GitHub Actions.
  Standard.

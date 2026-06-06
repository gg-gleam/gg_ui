# Registry

The registry is the data layer the (future) CLI reads to know what `gg-ui add
button` should do. **We adopt shadcn's schema verbatim**, with one extension
field for npm deps that some Gleam FFI components need. Same JSON shape, same
resolver semantics, different file extensions and dep ecosystem.

This doc describes the schema, where the JSON lives, and how a registry item
maps onto Gleam files. The CLI that *consumes* this is in [`cli.md`](cli.md).

## Two files

```
gg_ui_registry/
  registry.json              ← top-level manifest, lists every item
  items/
    button.json
    popover.json
    utils.json                 ← shared helper (gg_ui/helpers/cn — the only Gleam file copied)
    positioning.json
    theme-neutral.json         ← registry:theme item
    style-nova.json            ← registry:style item
    base-nova.json             ← registry:base item (the "preset")
    icon-lucide.json           ← registry:base or registry:item for icon library
```

`registry.json` is what users (and the CLI) hit first; it lists every item and
exposes the registry metadata. Each item's `files[].path` resolves against the
monorepo (`packages/gg_ui/src/gg_ui/...`, `packages/gg_base_ui/src/gg_base_ui/...`),
or a CDN copy of it. Same shape as
[shadcn's registry.json](https://ui.shadcn.com/r/registry.json).

## `registry.json` shape

Verbatim from shadcn:

```json
{
  "$schema": "https://ui.shadcn.com/schema/registry.json",
  "name": "gg_ui",
  "homepage": "https://gg-ui.dev",
  "items": [
    { "name": "button", "type": "registry:ui", ... },
    { "name": "popover", "type": "registry:ui", ... },
    ...
  ]
}
```

Items are usually inlined here for simple registries, or referenced as
`{ "name": "...", "registryUrl": "..." }` and resolved lazily. We'll inline
until the list gets long enough to be annoying in one file.

## `registry-item.json` — field-by-field

The per-item schema. Same as shadcn with **two changes** and the rest unchanged.

### Verbatim fields

```jsonc
{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "button",                          // unique slug
  "type": "registry:ui",                     // see "Types" below
  "title": "Button",
  "description": "Displays a button or a component that looks like a button.",
  "registryDependencies": ["utils"],         // other items in this registry
  "files": [...],                            // see "Files" below
  "cssVars": { "light": {...}, "dark": {...} },
  "css": { "@layer base": {...} },           // raw CSS the CLI appends to globals
  "tailwind": { "config": {...} }            // mostly unused with Tailwind v4
}
```

The resolver, ordering, and dependency graph behave identically to shadcn.
`registryDependencies` is recursive (button depends on `utils`, which gets
pulled in automatically).

### Changed: `dependencies`

In shadcn this is npm package names. In our registry it's **Hex package names**:

```jsonc
{
  "dependencies": ["lustre", "gva"]
}
```

The CLI runs `gleam add lustre` for each missing entry. The schema doesn't
care — it's just a string array — but the *interpretation* differs. The CLI
fork ([`cli.md`](cli.md)) is where the install command is wired up.

### Added: `npmDependencies`

Some headless components ship a small `<name>_ffi.ts`. If that FFI imports a
real npm package (e.g. `@floating-ui/dom` for tooltip positioning), the
consuming app needs it installed. We surface that with an extension field:

```jsonc
{
  "dependencies": ["lustre"],
  "npmDependencies": ["@floating-ui/dom"],
  "npmDevDependencies": ["@types/floating-ui__dom"]
}
```

The CLI runs `pnpm add @floating-ui/dom` (or detects npm/yarn/bun) for these.
The JSON-schema URL still validates because additionalProperties is open in
shadcn's schema — we add fields, we don't change existing ones.

### Files

Same shape as shadcn, different extensions:

```jsonc
{
  "files": [
    { "path": "packages/gg_ui/src/gg_ui/ui/button.gleam", "type": "registry:ui" }
  ]
}
```

`path` resolves against the monorepo root. `target` (optional) overrides where
the CLI writes the file in the consuming app; defaults to the configured
`aliases` prefix applied to the file's slug (see [`config.md`](config.md)).

Only the thin styled `ui/<name>.gleam` (and shared helpers) are copied — the
headless layer is **never** in `files` because it's a Hex dependency, not
copied source. See "Eject model" below.

## Item types

Same set as shadcn, with `tsx`/`jsx` replaced by `gleam`:

| `type`                | Meaning                                            | Lives at                                |
| --------------------- | -------------------------------------------------- | --------------------------------------- |
| `registry:ui`         | A component (button, popover, …)                   | `gg_ui/ui/<name>.gleam` (headless imported from `gg_base_ui`, not copied) |
| `registry:lib`        | A shared helper (cn, types, …)                     | `gg_ui/helpers/<name>.gleam`            |
| `registry:hook`       | A Lustre effect helper                             | `gg_ui/effects/<name>.gleam` (TBD)      |
| `registry:theme`      | A CSS-var palette (neutral, stone, …)              | `gg_ui/styles/base_colors/<name>.css` / `gg_ui/styles/themes/<name>.css` |
| `registry:style`      | A shape style overlay (nova, vega, luma, …)        | `gg_ui/styles/shapes/<name>.css`        |
| `registry:base`       | A composed preset (base-nova = headless+style+icon)| `bases/<name>.json` (no file, virtual)  |
| `registry:item`       | Catch-all for misc files (icons, fonts, …)         | anywhere                                |
| `registry:block`      | A multi-component example                          | `blocks/<name>/...`                     |

The CLI uses `type` to decide where to write and what to do post-write — e.g.
`registry:theme` appends `cssVars` to the user's CSS file, `registry:style`
adds an `@import`.

## A worked example: `button.json`

```jsonc
{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "button",
  "type": "registry:ui",
  "title": "Button",
  "description": "Displays a button or a component that looks like a button.",
  "dependencies": ["lustre", "gva", "gg_base_ui"],
  "registryDependencies": ["utils"],
  "files": [
    { "path": "packages/gg_ui/src/gg_ui/ui/button.gleam", "type": "registry:ui" }
  ]
}
```

When a user runs `gg-ui add button` against a project with
`components.json` declaring `aliases.ui = "my_app/components/ui"`, the CLI:

1. Resolves `registryDependencies: ["utils"]` → also fetch `utils.json` →
   writes `src/my_app/lib/utils.gleam`.
2. Reads `dependencies` → runs `gleam add lustre gva gg_base_ui`
   (skipping any already present in `gleam.toml`).
3. Reads `files` → writes the thin `ui/button.gleam` to
   `src/my_app/components/ui/button.gleam`.
4. Rewrites only the *copied* imports — `import gg_ui/helpers/cn` →
   `import my_app/lib/utils as cn`. The headless import
   `import gg_base_ui/button/button as base_button` **stays verbatim**:
   `gg_base_ui` is a real Hex dependency (added in step 2), exactly like a Base
   UI import survives a shadcn eject. The headless layer is never copied.

## Eject model

shadcn-faithful: ejecting copies the **thin styled `ui/<component>.gleam`** plus
the shared `helpers/cn` (the `utils` analogue) into the app, and adds
`gg_base_ui` as a Hex dependency. The headless layer in `gg_base_ui` is
**imported, never copied** — the same way shadcn imports Base UI rather than
vendoring it. The headless import line is left untouched by the rewrite.

Path-rewrite rules live in the CLI — see [`cli.md`](cli.md). The registry JSON
itself doesn't encode them; it just describes what files exist and how they
relate.

## Where files live

The monorepo splits the two layers into separate packages:

```
packages/
  gg_base_ui/                            ← LAYER 1, own Hex package (imported, never copied)
    src/gg_base_ui/<name>/<name>.gleam
    src/gg_base_ui/helpers/id_gen/id_gen.gleam
  gg_ui/                                 ← LAYER 2, the thin styled kit
    src/gg_ui/ui/<name>.gleam
    src/gg_ui/styles/shapes/<style>.css
    src/gg_ui/styles/base_colors/<name>.css
    src/gg_ui/styles/themes/<theme>.css
    src/gg_ui/helpers/cn.gleam
```

There's no `gg_ui_registry/` directory yet, and no `registry.json`. Adding it is
the next concrete step. Item paths reference these monorepo paths; when the
registry splits out to its own host, those paths get rewritten once (the files
themselves stay put; the registry just points elsewhere).

## What the registry is *not*

- **Not a package manifest.** `gleam.toml` is the Hex package manifest. The
  registry is a copy-paste manifest for the CLI. They coexist: the Hex
  package exposes the source as importable modules, and the same files are
  also addressable as registry items.
- **Not validated by `gleam build`.** It's plain JSON, parsed by the CLI and
  validated against the JSON schema. Bad registry items produce CLI errors,
  not Gleam compile errors.
- **Not a documentation source.** Docs are docs. The registry has
  `description` and `title` fields, but the docs site reads from `*.gleam`
  doc comments + examples, not from registry JSON.

## Open questions (for when we implement)

- **Motion layer ship story — TODO, no registry type yet.** Motion is the one
  styling axis with no `type` in the table above, and it must get one before the
  CLI ships. This is a real **divergence from shadcn**: shadcn's animation is
  inline `tw-animate-css` utilities living *in the component's className*, so it
  ejects automatically with the `.tsx` and the user wires nothing. Ours is a
  **native-CSS fragment** (`styles/motion/<component>.css`, keyed on the same
  `cn-*` selectors the component emits) that lives *outside* the component — and
  deliberately so (native `@starting-style` / `:popover-open` / `allow-discrete`
  can't be expressed as utilities, and they give real *exit* animation, which
  `tw-animate-css` can't without a JS `data-state`). The consequence: `gg-ui add
  tooltip` copies the component but **not** its motion, so an ejected component
  would render with no animation unless the CLI also applies the motion.
  **Goal: zero plumbing** — adding a component yields its motion automatically,
  exactly the way shadcn applies tokens/themes onto the user's stylesheet. Two
  vehicles, both already in the schema (pick one when we implement):
    1. **The `css` field** (`registry-item.json`'s "raw CSS the CLI appends to
       globals") — fold a component's motion CSS into its `registry:ui` item's
       `css`, so `add` inlines it into the user's globals. Motion travels *with*
       the component it belongs to — closest to shadcn's "it just comes with the
       component" feel.
    2. **An `@import`ed fragment** — treat motion like `registry:style` /
       `registry:theme`: ship `styles/motion/<component>.css` and have `add`
       append an `@import` to the user's CSS entry (mirrors how `apply` wires
       style/theme overlays in [`cli.md`](cli.md)).
  Also decide where the shared `:root` motion tokens (`--motion-duration-popover`,
  `--motion-ease`, the tooltip's inherited `--motion-duration-tooltip`) ship —
  most likely once, via the base preset. Tracked from the CLI side in
  [`cli.md`](cli.md) "Open questions".

- **Multiple registries.** shadcn's CLI supports third-party registries
  (`@your-org/registry`). We'll inherit that for free if we fork. Worth
  defining what a "Gleam-flavoured" third-party registry looks like — same
  schema, hosted JSON, namespaced item names.
- **Block items.** shadcn has `registry:block` for multi-file demos. Useful
  later for "here's a full settings page". Skip for v1.
- **Versioning.** shadcn pins items at "latest" by convention. We can do the
  same; revisit if anyone asks for version pinning.

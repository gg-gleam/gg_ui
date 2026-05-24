# `components.json`

The per-project config file the CLI reads to know where to write copied files,
which icon library to use, which style preset is active, and where the user's
CSS file lives. **Same filename and same schema as shadcn**, with Gleam-typed
values and a few fields dropped that don't apply.

This file lives at the **root of the consuming app**, not in this repo. We
document it here because it's the contract between the CLI and the consumer.

## The whole file

```jsonc
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "base-nova",
  "iconLibrary": "lucide",
  "tailwind": {
    "css": "src/styles.css",
    "baseColor": "neutral",
    "cssVariables": true
  },
  "aliases": {
    "ui": "my_app/components/ui",
    "components": "my_app/components",
    "lib": "my_app/lib",
    "utils": "my_app/lib/utils",
    "hooks": "my_app/effects"
  }
}
```

That's it. Everything in this file maps onto a real decision the CLI makes
when writing files.

## Field-by-field

### `$schema`

Keep shadcn's URL. The schema is permissive (open `additionalProperties`),
so our extensions (none, at the project-config level) won't invalidate.
Editor JSON-schema integration works out of the box.

### `style`

The active **base + style preset**, named after the same combinations shadcn
uses for its pre-built presets:

| Value           | Headless layer | Shape style |
| --------------- | -------------- | ----------- |
| `base-nova`     | `gg_base_ui`   | nova        |
| `base-vega`     | `gg_base_ui`   | vega        |
| `base-luma`     | `gg_base_ui`   | luma        |
| `base-sera`     | `gg_base_ui`   | sera        |
| `base-lyra`     | `gg_base_ui`   | lyra        |
| `base-mira`     | `gg_base_ui`   | mira        |
| `base-maia`     | `gg_base_ui`   | maia        |

shadcn uses `radix-nova` / `base-nova` because it has two engines (Radix UI and
Base UI). Our one headless layer is the `gg_base_ui` Hex package, so `base-` is
the only prefix — but the field shape stays compatible. If we ever add a second
engine, the mapping extends.

The CLI uses `style` to:

1. Resolve `registry:ui` items from `packages/gg_ui/src/gg_ui/ui/...`.
2. Pull in the `registry:style` overlay CSS (`styles/shapes/<style>.css`).
3. Pick the right preset's icon-library / base-color defaults when running
   `init`.

See [`styling.md`](styling.md) for what these names mean visually.

### `iconLibrary`

Which icon library this project uses. Values: `lucide`, `phosphor`, `tabler`,
`hugeicons`, `remixicon` (same set as shadcn).

The CLI uses this when rewriting `icon.placeholder(...)` calls inside copied
component source — see [`icons.md`](icons.md). It also decides which
`gg_ui_icons_<lib>` Hex package to add to `gleam.toml`.

### `tailwind.css`

Path (from the project root) to the user's Tailwind v4 entry CSS. The CLI
appends `@import` lines to this file when adding `registry:theme` and
`registry:style` items, and inlines `cssVars` into a `:root` / `.dark` block
if `cssVariables` is true.

### `tailwind.baseColor`

The active base color. Values: `neutral`, `stone`, `zinc`, `mauve`, `olive`,
`mist`, `taupe`. See [`themes.md`](themes.md).

The CLI uses this to:

1. Pick the default `registry:theme` to install if none is specified.
2. Generate the CSS-var dump when `cssVariables: true`.

### `tailwind.cssVariables`

If `true` (the default), themes are applied as `--background: oklch(...)`
CSS variables. If `false`, classes are emitted with raw OKLCH values inlined
(matches shadcn's "no CSS variables" mode). We always recommend `true`.

### `tailwind.config`

shadcn supports this for Tailwind v3 users. With v4, config is in CSS, not JS,
so this is **empty by default** in our world. We accept the field for
compatibility but don't write anything to it. The CLI warns if a user sets
it to a non-empty value.

### `aliases.*`

The most Gleam-specific section. In shadcn, these are TypeScript path aliases
(`@/components/ui`) that resolve via `tsconfig.json`'s `paths`. In Gleam,
**they're Gleam module paths**, which directly determine the filesystem
location.

| Alias key      | Example value             | Where files land                        |
| -------------- | ------------------------- | --------------------------------------- |
| `ui`           | `my_app/components/ui`    | `src/my_app/components/ui/*.gleam`      |
| `components`   | `my_app/components`       | `src/my_app/components/*.gleam`         |
| `lib`          | `my_app/lib`              | `src/my_app/lib/*.gleam`                |
| `utils`        | `my_app/lib/utils`        | `src/my_app/lib/utils.gleam`            |
| `hooks`        | `my_app/effects`          | `src/my_app/effects/*.gleam`            |

`utils` is the *full* module path (a file), not a directory — because that's
how shadcn treats it too (`@/lib/utils`). `hooks` we rename to `effects` in
practice because Lustre uses effects, not React-style hooks, but the JSON key
stays `hooks` for schema compatibility.

When the CLI writes a copied file, it rewrites the `import`s that point at
*copied* source — and leaves the headless import alone:

```gleam
// in the registry source (the thin styled ui/button.gleam):
import gg_base_ui/button/button as base_button
import gg_ui/helpers/cn

// after `gg-ui add button` with aliases above:
import gg_base_ui/button/button as base_button   // stays verbatim — Hex dependency
import my_app/lib/utils as cn
```

The rewrite rules are mechanical:

- `gg_ui/ui/<name>` → `<aliases.ui>/<name>`
- `gg_ui/helpers/cn` → `<aliases.utils>`
- `gg_ui/effects/<name>` → `<aliases.hooks>/<name>`
- `gg_base_ui/...` — **left untouched.** The headless layer is a real Hex
  dependency (the CLI runs `gleam add gg_base_ui`), imported not copied, exactly
  like a Base UI import survives a shadcn eject.
- everything else (`lustre/...`, `gleam/...`) stays put

## Dropped fields (vs shadcn)

shadcn has a few fields that have no Gleam meaning. We don't write them and
ignore them if present:

- **`rsc`** — React Server Components flag. Lustre's server-side rendering
  isn't RSC; it's a different model. The CLI does the right thing for both
  Lustre targets without needing this flag.
- **`tsx`** — Toggles `.tsx` vs `.jsx` extensions. We always write `.gleam`.

## How the CLI reads it

```ts
// pseudocode
const config = await readComponentsJson(cwd)
const registry = await fetchRegistry(config.style)
const item = await registry.resolve("button", config)
await writeItemFiles(item, config.aliases, cwd)
await maybeRewriteIcons(item, config.iconLibrary)
await installDeps(item.dependencies, "hex")
await installDeps(item.npmDependencies, "npm")
```

The CLI fork inherits all of this from shadcn — we mostly change the
`resolveAliasPath` function (TypeScript-`paths` → Gleam-module-path) and
the `installDeps` call (`pnpm add` → `gleam add` plus `pnpm add` for npm
deps). See [`cli.md`](cli.md).

## Authoring guidance

If you're writing a registry item, design as if the user might have any of
these aliases configured. That means:

1. **Never hard-code `gg_ui/...` (copied) module paths in import strings.**
   Imports of copied source route through the alias-rewrite rules above. The
   `gg_base_ui/...` headless import is the exception — it's a Hex dependency and
   stays verbatim.
2. **Use relative paths sparingly.** They survive the rewrite, but they're
   less readable. Prefer absolute module paths so the rewrite is uniform.
3. **Don't assume `aliases.utils == "lib/utils"`.** Always import the helper
   under whatever name `gg_ui/helpers/cn` resolves to.

The CLI enforces (1) and (3) by running the rewrite even when paths look
"already right" — predictability over cleverness.

## Open questions

- **One config file, or split?** shadcn has just `components.json`. Gleam
  projects already have `gleam.toml` — should `components.json` move into a
  `[tool.gg_ui]` section there? Tempting, but the schema would no longer be
  reusable. **Decision: keep `components.json`.** Gleam's TOML can grow a
  small `[tool.gg_ui]` section later for *Gleam-specific* knobs the JSON
  schema can't express (e.g. selecting BEAM-only vs JS-only targets per
  component).
- **Path-rewrite failure modes.** What happens if the user's `aliases.utils`
  points at a path that doesn't exist? The CLI creates the directory.
  What about conflicting writes (file already exists, different content)?
  shadcn prompts. We do the same. See [`cli.md`](cli.md).

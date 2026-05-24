# Monorepo layout

How the `gg_ui` repo is structured as a multi-package monorepo. The core
split — headless Hex package, thin styled kit, docs host — is **realized**.
A published CLI and a deployed docs app are still **deferred**, but designed
up front so the docs in this directory, the registry schema, and the (future)
CLI all aim at the same target.

## The current shape

```
gg_ui/                                   ← repo root = pure pnpm-workspace orchestrator
  package.json                            (workspace scripts; shared devDeps: biome, stylelint)
  pnpm-workspace.yaml                     (packages: ["apps/*"])
  pnpm-lock.yaml
  biome.json                              (Biome owns .ts/.json — whole tree)
  .stylelintrc.json                       (stylelint owns .css — whole tree)

  apps/
    storybook/                            ← the Storybook host APP (gleam.toml gg_ui_storybook,
      gleam.toml                            package.json @gg_ui/storybook; path-deps both packages)
      package.json                        (storybook/vite/vitest deps + app-local scripts)
      vite.config.ts                      (vite-plugin-gleam compiles the graph)
      vitest.config.ts  tsconfig.json
      .storybook/                         (Storybook 10 config + lustre-mount)
      src/
        gg_ui.css                         ← the CSS ENTRY (imports Tailwind, then fragments)
        stories/<component>/               (<c>.stories.ts + <c>.gleam)

  packages/
    gg_base_ui/                           ← LAYER 1 — headless Hex package
      gleam.toml                          (deps: gleam_stdlib, lustre)
      src/gg_base_ui/
        button/button.gleam
        popover/{popover.gleam,popover_ffi.ts}
        positioning/positioning.gleam
        arrow/{arrow.gleam,arrow_ffi.ts}
        helpers/id_gen/                    (the useId analogue)
      test/                                (gleeunit — headless tests live here)

    gg_ui/                                ← LAYER 2 — thin styled kit Hex package
      gleam.toml                          (deps: gleam_stdlib, lustre, gva,
      src/gg_ui/                                 gg_base_ui [path]; no target = universal)
        ui/{button,popover}.gleam          (emit cn-* class names via gva + cn)
        helpers/cn.gleam                   (pure-Gleam class join — no tailwind-merge)
        styles/                            (CSS FRAGMENTS — no @import "tailwindcss")
          tokens.css                       (@theme inline color map + --radius)
          shapes/<style>.css + shapes/<style>/{button,popover}.css
          base_colors/<name>.css
          themes/<name>.css
          motion.css + motion/<component>.css

  dev-docs/                               ← (where you are now)
    README.md vision.md composition.md registry.md
    config.md styling.md themes.md icons.md cli.md monorepo.md
```

The headless layer is its **own Hex package** (`gg_base_ui`) and is **imported,
never ejected** — exactly the way shadcn imports Base UI. `gg_ui` is the thin
styled kit; it **path-depends** `gg_base_ui` and is the layer a future CLI
copies into apps. The **`apps/storybook`** app (`gg_ui_storybook`) is the
Storybook host: it owns the CSS **entry**, the Storybook stories, and the
Storybook-specific build config, and it path-deps both packages so Storybook can
render the styled kit. The repo root owns **no Gleam package** — it's a pure
pnpm-workspace orchestrator (workspace scripts + the shared biome/stylelint
config that lints the whole tree).

### Still deferred

- `packages/gg_ui_cli/` — the npm-published CLI (fork of `packages/shadcn`).
  See [`cli.md`](cli.md).
- `apps/docs/` — a deployed docs site (the `ui.shadcn.com` analogue). The
  `apps/` layer + the `apps/*` workspace glob already exist (Storybook lives
  there); the docs app is just not built yet.
- `gg_ui_registry/` — the generated registry JSON the CLI reads.

## CSS: fragments vs entry

The split between **library fragments** and the **consumer entry** is the
load-bearing rule:

- **Library packages ship fragments** — pure CSS with **no `@import
  "tailwindcss"`**. Every file under `gg_ui/styles/` is a fragment.
- **A consumer writes one entry** that imports Tailwind first, then the
  fragments. Storybook's entry is `src/docs/gg_ui.css`; a real app's entry is
  assembled by the CLI (later). Nested `@import` + `@apply` resolve fine
  through the chain.

Three orthogonal axes plus motion, all toggled by classes on the root and
matching shadcn's vocabulary (Style / Base Color / Theme):

- **Style** (shape — padding/radius/density/casing) → per-component fragments
  `styles/shapes/<style>/{button,popover}.css` + a thin index
  `styles/shapes/<style>.css`. Class `.style-<name>`. 7 styles: nova, vega,
  luma, sera, lyra, mira, maia.
- **Base Color** (neutral palette + a default neutral `--primary`) →
  `styles/base_colors/<name>.css`. Class `.base-color-<name>`. 7: neutral,
  stone, zinc, mauve, olive, mist, taupe.
- **Theme** (accent — overrides `--primary` on top of the base color) →
  `styles/themes/<name>.css`. Class `.theme-<name>`. 17 accents, imported
  after base colors.
- **Motion** (shared, orthogonal to shape/color) → `styles/motion/<component>.css`
  + `styles/motion.css` index. Native: `:popover-open` + `@starting-style` +
  `transition-behavior: allow-discrete`.
- `styles/tokens.css` — the shared `@theme inline { --color-*: var(--*) }`
  mapping + `:root { --radius }`.

Component variants are **class names** (`cn-button-variant-default`), not
`data-variant` attributes; cross-rule conflicts resolve by source order.

## Why split at all

Three independent reasons:

1. **Different ecosystems.** Gleam packages publish to Hex. The CLI publishes
   to npm. Forcing them into one Hex package or one npm package would be ugly;
   the monorepo lets each live in its native distribution channel.
2. **The import-not-eject boundary.** `gg_base_ui` is a real Hex dependency
   that survives an eject verbatim — keeping it a separate package makes the
   headless/styled boundary a publishing boundary, not just a directory one.
3. **CI surface area.** The CLI tests (when it lands) are TypeScript and don't
   need a Gleam build. The Gleam packages don't need npm. Per-package CI keeps
   each pipeline fast and independent.

## Why this shape, not another

A few alternatives we considered and rejected:

- **Single Hex package, CLI inside it.** Doesn't work — Hex doesn't ship npm
  binaries. The CLI has to be its own npm package.
- **Headless + styled in one Hex package.** Loses the import-not-eject model:
  the headless layer must be an independent dependency so an ejected `ui/`
  file can keep its `import gg_base_ui/...` verbatim.
- **One Hex package per UI component.** Way too granular — `gleam add
  gg_ui_button` is annoying when you want six components. shadcn doesn't split
  per-component on npm; we don't either on Hex.

## What's left to do

The repo already runs everything it needs to iterate. The remaining splits are
incremental:

1. **Stand up `gg_ui_registry/`** — a hand-written `registry.json` describing
   what already exists, served by the (future) docs site.
2. **Write `packages/gg_ui_cli/`** — fork shadcn's `packages/shadcn` and apply
   the diff described in [`cli.md`](cli.md). Publish to npm.
3. **Deploy `apps/docs/`** — render the registry JSON into pages and embed
   Lustre previews.

These are overhead; we pay them when the value exceeds the cost.

## Workspace mechanics

```yaml
# pnpm-workspace.yaml (when the npm-side grows)
packages:
  - "apps/*"
  - "packages/*"
  - "!**/test/**"
  - "!**/fixtures/**"
```

The Gleam packages are referenced via **path deps**: `gg_ui_docs` (root)
path-deps both `gg_base_ui` and `gg_ui`, and `gg_ui` path-deps `gg_base_ui`.

CI and local commands run **per package** for Gleam:

- `gg_base_ui` — `cd packages/gg_base_ui && gleam test`, `gleam format --check`.
- `gg_ui` — `cd packages/gg_ui && gleam test`, `gleam format --check`.
- `gleam build` **at the root** compiles the whole path-dep graph.
- `pnpm dev` / `pnpm build` run Storybook (vite-plugin-gleam compiles the
  graph). `pnpm lint` = `stylelint … && biome check`; `pnpm format` =
  `stylelint --fix … && biome format`.

A future `packages/gg_ui_cli` adds vitest + Biome; a future `apps/docs` adds
its own build. A top-level `turbo.json` can orchestrate them, but it's
optional.

## Open questions

- **Hex publishing automation.** Changesets + a GitHub Action would mirror
  shadcn's `.changeset/` flow. Set up when both Hex packages are ready to
  publish in lockstep-ish.
- **Versioning across packages.** Independent versions are fine — `gg_ui`,
  `gg_base_ui`, and a future CLI don't have to march in lockstep. The registry
  JSON should track which `gg_ui` versions an item is compatible with (a future
  field; defer).

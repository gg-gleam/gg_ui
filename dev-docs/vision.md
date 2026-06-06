# Vision

What we're building, why it's shaped like it is, and which parts are deferred.
Read this first. The other docs in this directory are deep dives into the boxes
this one names.

## TL;DR

`gg_ui` is **shadcn/ui for Gleam + Lustre**. Same layered model, same
copy-paste-into-your-app distribution story, same registry schema — adapted
where Gleam's type system and dual-target compilation (JS + BEAM) force a
different implementation.

If you know shadcn, the mapping is:

| shadcn concept                              | gg_ui equivalent                                             |
| ------------------------------------------- | ------------------------------------------------------------ |
| `packages/shadcn` (CLI on npm)              | `gg-ui` CLI on npm (deferred, forked from `packages/shadcn`) |
| `apps/v4/registry/` (registry source)       | `packages/gg_ui/` modules + `gg_ui_registry/*.json` (deferred) |
| `components.json` (per-project config)      | `components.json` — same filename, Gleam values              |
| `registry-item.json` schema                 | same schema + `npmDependencies` extension                    |
| Base (Base UI) imported, never ejected      | `packages/gg_base_ui` — its own Hex package, imported verbatim — see [composition.md](composition.md) |
| Styles (nova / vega / luma / …)             | same names, per-component shape fragments in `styles/shapes/<style>/` |
| Base Color (neutral / stone / zinc / …)     | same names, `styles/base_colors/<name>.css`                  |
| Theme (amber / blue / emerald / …)          | same names (accents), `styles/themes/<name>.css`             |
| Icon libraries (lucide / phosphor / …)      | same set, **inline SVG** generated from upstream JSON        |

## The layers, top to bottom

```
┌──────────────────────────────────────────────────────────────┐
│  Templates             starter Lustre projects                │  (deferred)
│  templates/lustre-spa/, templates/lustre-server/, …           │
├──────────────────────────────────────────────────────────────┤
│  CLI                   gg-ui init / add / view / search       │  (deferred)
│  packages/gg_ui_cli/   fork of shadcn's packages/shadcn       │
├──────────────────────────────────────────────────────────────┤
│  Registry              registry.json + items/*.json           │  (deferred)
│  gg_ui_registry/       same schema as shadcn                  │
├──────────────────────────────────────────────────────────────┤
│  Styled kit            thin: cn-* class names                 │  ← we are here
│  packages/gg_ui/ — gg_ui/ui/<name> + gg_ui/styles/ fragments  │
├──────────────────────────────────────────────────────────────┤
│  CSS axes              Style / Base Color / Theme + motion    │  ← we are here
│  gg_ui/styles/{shapes,base_colors,themes,motion,tokens}       │
├──────────────────────────────────────────────────────────────┤
│  Headless layer        behavior + a11y, unstyled              │  ← we are here
│  packages/gg_base_ui/ — gg_base_ui/<name>/<name>              │
└──────────────────────────────────────────────────────────────┘
```

The repo is a monorepo of three packages: `packages/gg_base_ui` and
`packages/gg_ui` (the two library layers below), plus the **repo root**, which is
the `gg_ui_docs` host package that path-depends both, holds the CSS entry
(`src/docs/gg_ui.css`), the stories (`src/stories/<component>/`), and the Node
tooling (`.storybook/`, `vite.config.ts`, `biome.json`, `.stylelintrc.json`).

The boundaries are deliberate. Each layer is consumable on its own:

- **Headless** (`packages/gg_base_ui`) is engine-agnostic Gleam in its **own Hex
  package**, **imported, never ejected** — exactly like shadcn imports Base UI.
  No Tailwind, no CSS, ships no stylesheet. Useful on its own for someone
  bringing their own design system. FFI `@external` paths are **relative**.
- **Styled** (`packages/gg_ui`) is the shadcn-recipe layer. Path-depends
  `gg_base_ui` and imports it + `gva` + `cn`; emits `cn-*` class names, never
  raw Tailwind. Ships the CSS **fragments** under `gg_ui/styles/`. The future
  CLI copies the thin `ui/<name>.gleam` + `helpers/cn` into the consuming app;
  the headless import stays verbatim (`gg_base_ui` remains a Hex dependency).
- **CSS axes** are just CSS fragments shipped by `gg_ui` — see below — assembled
  into one entry by a consumer.
- **Registry** is data: JSON manifests describing what each item is and what
  it depends on. The CLI is the only consumer.
- **CLI** is a TypeScript Node binary distributed via npm. Forked from shadcn's
  CLI to inherit years of edge-case handling.

## The CSS model: fragments vs entry

Library packages ship **fragments** — pure CSS with **no `@import "tailwindcss"`**.
A *consumer* writes **one entry** that imports Tailwind and then the fragments;
nested `@import` + `@apply` resolve through the chain. Storybook's entry is
`src/docs/gg_ui.css`; a real app's entry is assembled by the CLI (later).

Three orthogonal axes plus motion, all toggled by classes on the root, matching
shadcn's vocabulary:

- **Style** (shape: padding/radius/density/casing) → per-component fragments
  `styles/shapes/<style>/<component>.css` + a thin `styles/shapes/<style>.css`
  index. Class `.style-<name>` (nova, vega, luma, sera, lyra, mira, maia).
- **Base Color** (neutral palette + a default neutral `--primary`) →
  `styles/base_colors/<name>.css`. Class `.base-color-<name>` (neutral, stone,
  zinc, mauve, olive, mist, taupe).
- **Theme** (accent — overrides `--primary` on top of the base color) →
  `styles/themes/<name>.css`, imported after base colors. Class `.theme-<name>`
  (amber, blue, emerald, … — 17 accents).
- **Motion** (shared, orthogonal) → `styles/motion/<component>.css` +
  `styles/motion.css` index. **Native**: `:popover-open` + `@starting-style` +
  `transition-behavior: allow-discrete` — not tw-animate-css.
- `styles/tokens.css` — the shared `@theme inline { --color-*: var(--*) }`
  mapping + `:root { --radius }`.

Component variants are **class names** (`cn-button-variant-default`), not
`data-variant` attributes; cross-rule conflicts resolve by source order.

## Two consumption modes

A Gleam project consuming `gg_ui` does one of two things:

1. **Import as a normal Hex dependency.** `gleam add gg_ui` and import
   `gg_ui/ui/button`. You don't own the source; upgrades are
   per-version. Works today.
2. **Copy via the CLI (future).** `gg-ui add button` copies the thin
   `ui/button.gleam` + `helpers/cn` into your project and runs
   `gleam add gg_base_ui`. The headless import
   (`import gg_base_ui/button/button as base_button`) stays verbatim — headless
   is never copied into your code, exactly like a Base UI import survives a
   shadcn eject. You own the styled file, the rest of the registry resolves
   against your local copy. This is the shadcn model.

Both layouts work with the same source files in this repo — see
[`registry.md`](registry.md).

## Two compilation targets

Lustre runs on **both** JS (SPA / browser) and BEAM (server-rendered HTML for
"server components"). Everything we ship has to compile on both, which has two
consequences worth flagging up front:

- **No FFI in the styled layer.** Headless modules can have a small
  `<name>_ffi.ts` next to them (loaded on the JS target only, via Lustre
  effects), referenced by a **relative** `@external` path. Styled modules stay
  pure Gleam.
- **Icons can't be JS imports.** A `lucide-react` style approach would only
  work in SPAs. We generate inline-SVG Gleam modules from upstream icon JSON
  instead — see [`icons.md`](icons.md).

## What's in scope now vs deferred

Built and working:

- Monorepo: `packages/gg_base_ui` (headless Hex package, imported not ejected),
  `packages/gg_ui` (thin styled kit, path-depends `gg_base_ui`), and the repo
  root as the `gg_ui_docs` host
- Headless layer for `button`, `popover`, `positioning`, `arrow` +
  `gg_base_ui/helpers/id_gen` — relative TypeScript FFI, no stylesheet
- Thin styled layer for `button`, `popover` in `gg_ui/ui/` (emit `cn-*` class
  names via `gva` + `cn`, never raw Tailwind)
- The fragments-vs-entry CSS model: `gg_ui/styles/` ships fragments
  (`shapes/`, `base_colors/`, `themes/`, `motion/`, `tokens.css`); the
  `gg_ui_docs` host owns the entry `src/docs/gg_ui.css`
- The three CSS axes (Style / Base Color / Theme) + native motion, toggled by
  root classes — see [`styling.md`](styling.md), [`themes.md`](themes.md)
- Storybook + Vite + `vite-plugin-gleam` toolchain; stylelint owns `.css`,
  Biome owns `.ts`/`.json`
- `helpers/cn` — a pure-Gleam class join (semantic `cn-*` names don't conflict,
  so no tailwind-merge needed; keeps the kit dependency-free and dual-target)
- Composition model — see [`composition.md`](composition.md)

Planned next (no CLI required):

- First inline-icon module (`gg_ui/icons/lucide.gleam`) generated from upstream
  — see [`icons.md`](icons.md)
- Hand-authored `gg_ui_registry/registry.json` + per-item JSON describing the
  existing components — see [`registry.md`](registry.md)
- `components.json` schema documented and an example consumer wiring it up
  manually — see [`config.md`](config.md)

Deferred (CLI work):

- `gg-ui init` / `add` / `view` / `search` — see [`cli.md`](cli.md)
- Transformer pipeline (icon rewriting, import resolution)
- MCP server
- `packages/gg_ui_cli` (npm), the generated `gg_ui_registry/` (JSON), a deployed
  `apps/docs`, and `templates/` — see [`monorepo.md`](monorepo.md)

The deferred items don't change the architecture; they just turn manual copy
of files into a `gg-ui add` command. The docs in this directory are written
so the future CLI implementer has a fully-specified target.

## How decisions get made

Three rules, in order:

1. **Reuse shadcn's schema and CLI surface where it fits.** Same filenames,
   same JSON shapes, same command names. Compatibility isn't a side effect;
   it's the point. If we deviate, it's because Gleam genuinely can't express
   the original — not because we have a slightly nicer idea.
2. **Both targets, or it doesn't ship.** Anything in the styled layer must
   compile on JS *and* BEAM. FFI lives behind the headless boundary or in
   the consuming app.
3. **Layers don't reach up.** Headless never imports styled. Styled never
   imports the registry. The registry doesn't know about the CLI. Each layer
   has a strictly smaller dependency set than the one above.

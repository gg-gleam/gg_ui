# gg_ui

A headless-first UI kit for [Lustre](https://lustre.build), in the spirit of
[Base UI](https://base-ui.com) + [shadcn/ui](https://ui.shadcn.com) — but for
Gleam.

> **Status: early.** The first primitive (popover) is in place along with the
> full toolchain. Tooltip, combobox and chips — and the companies selector that
> consumes them — are next.

## The vision

gg_ui is built in layers, so you can drop down to raw behaviour or stay in
batteries-included styling:

1. **Headless primitives** — pure state machines + accessibility + unstyled
   view builders. They own behaviour, not looks, and assume the host app
   provides Tailwind. The "Base UI / Radix" layer.
2. **Styled components** — shadcn-flavoured components built on the
   primitives with Tailwind classes and theme tokens. Meant to be
   **copy-paste-able** into consuming apps, shadcn-style — you own the
   markup.
3. **Theme tokens** — shadcn's token model (`--background`/`--foreground`,
   `--popover`, `--ring`, …) reverse-engineered onto Tailwind v4, with
   light/dark support. Shipped as CSS **fragments** under
   `packages/gg_ui/src/gg_ui/styles/` (tokens, base colors, themes, shapes,
   motion) and assembled by a consumer entry such as
   [`apps/storybook/src/gg_ui.css`](apps/storybook/src/gg_ui.css).
4. **A generator CLI (future).** Not built yet. The end goal is a
   shadcn-style CLI (`gg-ui add popover`) that copies the styled component
   source into your app so you own and can edit it, rather than importing
   it as an opaque dependency. Until then, the styled layer is consumed as
   a normal module.

For the long-form architecture — registry schema, `components.json`
mapping, icon strategy, CLI plan, monorepo layout — see
[`dev-docs/`](dev-docs/README.md), starting with
[`dev-docs/vision.md`](dev-docs/vision.md).

### `gg_base_ui` vs `gg_ui`

The boundary is now a **package boundary**: headless lives in its own Hex
package, `gg_base_ui`, which is **imported, never ejected** — exactly like
shadcn imports Base UI. It's pure behaviour + a11y, reusable under any design
system, with a stable API; it ships **no stylesheet** and never imports
`styles/`. The thin `gg_ui` package composes that behaviour + `cn-*` class
names into a visual opinion — and `ui/` is the layer the future CLI copies into
apps (the `gg_base_ui` import survives the eject verbatim). A consumer picks
their level: `gg_base_ui` (bring your own CSS) or `gg_ui` (`ui/` + `styles/`
fragments, batteries included). See
[`dev-docs/composition.md`](dev-docs/composition.md) for the full model.

## Layout

A pnpm + Gleam monorepo: two libraries under `packages/`, consumer apps under
`apps/` (the `gg_ui_storybook` app wires the libraries together for Storybook),
and the repo root as a pure pnpm-workspace orchestrator.

```
packages/gg_base_ui/         # LAYER 1 — headless: own Hex package, imported, never ejected
  src/gg_base_ui/
    button/button.gleam      # headless button: type/disabled/role wiring
    popover/popover.gleam    # state + view: native Popover API + toggle-sync
    popover/popover_ffi.ts   # tiny: imperative show()/hide() escape hatch (relative path)
    positioning/             # shared: anchor a floating element (native CSS anchor pos)
    arrow/                   # shared decorative arrow primitive
    helpers/id_gen/          # the useId analogue
  test/                      # gleeunit tests live in this package
packages/gg_ui/              # LAYER 2 — thin styled kit, path-depends gg_base_ui
  src/gg_ui/
    ui/button.gleam          # gva → "cn-button cn-button-variant-* cn-button-size-*"
    ui/popover.gleam         # cn-popover* names; native-first anatomy preserved
    helpers/cn.gleam         # pure-Gleam class join (no tailwind-merge dep)
    styles/                  # CSS FRAGMENTS (no @import "tailwindcss")
      tokens.css             #   shared @theme inline mapping + --radius scale
      base_colors/<name>.css #   neutral palette (.base-color-<name>)
      themes/<name>.css      #   accent override of --primary (.theme-<name>)
      shapes/<style>.css     #   per-style index → shapes/<style>/{button,popover}.css
      motion/ + motion.css   #   native :popover-open + @starting-style motion
apps/storybook/              # Storybook host APP — own gleam.toml (gg_ui_storybook) + package.json
  src/gg_ui.css              #   the CSS ENTRY: @import tailwindcss then the fragments
  src/stories/<component>/   #   Storybook stories (controls .stories.ts + Gleam mount)
  .storybook/                #   Storybook 10 config + Lustre mount helper
  vite.config.ts vitest.config.ts tsconfig.json
package.json pnpm-workspace.yaml  # repo root: workspace orchestrator (no gleam.toml)
biome.json .stylelintrc.json      #   shared lint/format config (whole tree)
dev-docs/                    # architecture: vision, registry, CLI plan, monorepo, etc.
```

## Native-first: top layer + CSS anchor positioning

The popover leans on the platform instead of a JS positioning library:

- **Layering & dismissal** use the native [Popover
  API](https://developer.mozilla.org/en-US/docs/Web/API/Popover_API). The
  content carries `popover="auto"`, so the browser promotes it to the **top
  layer** — escaping any `overflow`/`transform` clipping ancestor with no portal
  — and handles light-dismiss (outside-click + Escape) for free.
- **Positioning** uses native [CSS Anchor
  Positioning](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_anchor_positioning)
  (`anchor-name` / `position-anchor` / `position-area` / `position-try`), in the
  shared `gg_base_ui/positioning` module. **No positioning JS.**

The payoff is that a popover is just markup + CSS + attributes, which means it
**renders server-side** with no client effect. CSS anchor positioning is
Chromium-first today; because positioning lives behind `core/positioning`, a
Floating UI strategy can slot in later for cross-browser support without
touching the components that consume it.

Open/close is **configurable**: declarative by default (`popovertarget` button +
the `toggle` event, no JS), with an imperative `show()/hide()` escape hatch
(`gg_base_ui/popover/popover_ffi.ts`) for controlled cases like a combobox.

### Positioning is a primitive, not a popover feature

`gg_base_ui/positioning` is shared on purpose. A **tooltip** is *not* a popover-on-hover
— it's hover **and** focus triggered, non-interactive (`role="tooltip"` +
`aria-describedby`, no focusable content), and has open/close delays — so it'll
land as a **sibling** of popover that reuses the same positioning + top layer,
mirroring how Base UI factors a shared `Positioner` across Popover, Tooltip and
Menu. On touch (no hover), tooltips don't open on tap; touch-critical info
should use a popover instead.

## FFI

What little FFI exists is **TypeScript**, referenced with a **relative**,
extension-less path (so it travels with the package, ejected or not):

```gleam
@external(javascript, "./popover_ffi", "showPopover")
fn show_popover(content_id: String) -> Nil { Nil }
```

`gleam build` passes that path through verbatim; Vite (via `vite-plugin-gleam`)
resolves the sibling `popover_ffi.ts` and transpiles it. Each binding keeps a
Gleam fallback body so the package compiles on **every** target; the fallbacks
never run because Lustre effects execute client-side. Biome formats/lints the
`.ts`; `tsc --noEmit` type-checks it — no separate compile-to-`.mjs` step.

## Toolchain

- **Gleam** → JS, via [`vite-plugin-gleam`](https://github.com/gleam-br/vite-plugin-gleam).
- **Vite** (rolldown) is the build system and dev server.
- **Tailwind v4** via `@tailwindcss/vite`.
- **TypeScript + Biome** for the `.ts`/`.json` surface; **stylelint** for `.css`.

```sh
pnpm install
pnpm dev         # Storybook on :6006
pnpm build       # static Storybook -> ./storybook-static
pnpm typecheck   # tsc --noEmit
pnpm lint        # stylelint .css + biome check .ts/.json
pnpm format      # stylelint --fix + biome format
gleam test       # pure-module tests, run per package (cd packages/gg_base_ui && gleam test)
```

`gleam build` from `apps/storybook` compiles the whole path-dependency graph
(`gg_ui_storybook` → `gg_ui` → `gg_base_ui`); the repo root is not a Gleam
package. The root `pnpm` scripts delegate to the app via `pnpm --filter
@gg_ui/storybook …` (`dev`/`build`/`test:stories`) and `pnpm -r …` (`typecheck`).

Stories live in `apps/storybook/src/stories/<component>/` as two files: a
`*.stories.ts` (Storybook `meta`/controls) and a `*.gleam` (the `mount_*` render
functions). Each renders through `.storybook/lustre-mount.ts`, which spins up a
fresh `<div>` and hands its selector to a `mount_*` function — a small Lustre app
per variant. Storybook reuses the app's `vite.config.ts` (via
`@storybook/html-vite`) so `.gleam` imports + Tailwind work inside stories; the
app's `src/gg_ui.css` entry resolves the theme tokens.

## Consuming gg_ui (preview)

While unpublished, the plan is to add the two packages as Gleam **path
dependencies** and import the styled components from `gg_ui`. Because library
packages ship CSS **fragments** (no bundled Tailwind), the consuming app writes
**one entry** stylesheet that `@import`s Tailwind and then the fragments it
wants — mirroring `apps/storybook/src/gg_ui.css` — and builds with Vite for FFI
resolution. A future CLI assembles that entry automatically. The exact
cross-package story is being finalised alongside the first consumer (a companies
selector).

## License

MIT.

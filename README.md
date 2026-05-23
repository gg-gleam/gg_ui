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

1. **Core primitives** — pure state machines + accessibility + unstyled view
   builders. They own behaviour, not looks, and assume the host app provides
   Tailwind. The "Base UI / Radix" layer.
2. **Styled components** — shadcn-flavoured components built on the primitives
   with Tailwind classes and theme tokens. Meant to be **copy-paste-able** into
   consuming apps, shadcn-style — you own the markup.
3. **Theme tokens** — shadcn's token model (`--background`/`--foreground`,
   `--popover`, `--ring`, …) reverse-engineered onto Tailwind v4, with
   light/dark support. See [`src/gg_ui/theme.css`](src/gg_ui/theme.css).
4. **A generator CLI (future).** Not built yet. The end goal is a shadcn-style
   CLI (`gg_ui add popover`) that copies the styled component source into your
   app so you own and can edit it, rather than importing it as an opaque
   dependency. Until then, the styled layer is consumed as a normal module.

### `core/` vs `styled/`

The boundary is deliberate: **`core/` never imports `styled/` or `theme.css`.**
Core is pure behaviour, reusable under any design system, with a stable API.
Styled composes core + tokens into a visual opinion — and it's the layer the
future CLI copies into apps. A consumer picks their level: `core` (bring your
own CSS) or `styled` (batteries included).

## Layout

```
src/gg_ui/
  core/                    # behaviour + a11y + DOM mechanics, unstyled
    positioning.gleam      # shared: anchor a floating element (native CSS anchor positioning). Pure, no FFI.
    popover.gleam          # state + view: native Popover API + positioning + toggle-sync
    popover_ffi.ts         # tiny: imperative show()/hide() escape hatch only
  styled/
    popover.gleam          # shadcn-styled trigger + panel
  theme.css                # design tokens (shadcn model, Tailwind v4, light/dark)
playground/                # Vite dev playground (mounts the styled components)
test/                      # gleeunit tests for the pure modules
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
  shared `core/positioning` module. **No positioning JS.**

The payoff is that a popover is just markup + CSS + attributes, which means it
**renders server-side** with no client effect. CSS anchor positioning is
Chromium-first today; because positioning lives behind `core/positioning`, a
Floating UI strategy can slot in later for cross-browser support without
touching the components that consume it.

Open/close is **configurable**: declarative by default (`popovertarget` button +
the `toggle` event, no JS), with an imperative `show()/hide()` escape hatch
(`core/popover_ffi.ts`) for controlled cases like a combobox.

### Positioning is a primitive, not a popover feature

`core/positioning` is shared on purpose. A **tooltip** is *not* a popover-on-hover
— it's hover **and** focus triggered, non-interactive (`role="tooltip"` +
`aria-describedby`, no focusable content), and has open/close delays — so it'll
land as a **sibling** of popover that reuses the same positioning + top layer,
mirroring how Base UI factors a shared `Positioner` across Popover, Tooltip and
Menu. On touch (no hover), tooltips don't open on tap; touch-critical info
should use a popover instead.

## FFI

What little FFI exists is **TypeScript**, referenced with an absolute,
extension-less path:

```gleam
@external(javascript, "/src/gg_ui/core/popover_ffi", "showPopover")
fn show_popover(content_id: String) -> Nil { Nil }
```

`gleam build` passes that path through verbatim; Vite (rooted at this package)
resolves `/src/gg_ui/core/popover_ffi.ts` and transpiles it. Each binding keeps
a Gleam fallback body so the package compiles on **every** target; the fallbacks
never run because Lustre effects execute client-side. Biome formats/lints the
`.ts`; `tsc --noEmit` type-checks it — no separate compile-to-`.mjs` step.

## Toolchain

- **Gleam** → JS, via [`vite-plugin-gleam`](https://github.com/gleam-br/vite-plugin-gleam).
- **Vite** (rolldown) is the build system and dev server.
- **Tailwind v4** via `@tailwindcss/vite`.
- **TypeScript + Biome** for the FFI surface.

```sh
pnpm install
pnpm dev         # Vite dev playground
pnpm build       # production bundle
pnpm typecheck   # tsc --noEmit
pnpm lint        # biome check
gleam test       # pure-module tests
```

## Consuming gg_ui (preview)

While unpublished, the plan is to add it to a host app as a Gleam **path
dependency** and import the styled components. The host imports
`src/gg_ui/theme.css` for the tokens and (for FFI resolution) builds with Vite.
The exact cross-package FFI resolution story is being finalised alongside the
first consumer (a companies selector).

## License

MIT.

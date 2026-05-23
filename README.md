# gg_ui

A headless-first UI kit for [Lustre](https://lustre.build), in the spirit of
[Base UI](https://base-ui.com) + [shadcn/ui](https://ui.shadcn.com) — but for
Gleam.

> **Status: early.** The first primitive (popover) is in place along with the
> full toolchain. Combobox and chips — and the companies selector that consumes
> them — are next.

## The vision

gg_ui is built in layers, so you can drop down to raw behaviour or stay in
batteries-included styling:

1. **Headless primitives** — pure state machines + accessibility + unstyled view
   builders. They own behaviour, not looks, and assume the host app provides
   Tailwind. Universal in the Lustre sense (see [Universal & FFI](#universal--ffi)).
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

## Layout

```
src/gg_ui/
  popover.gleam              # headless: State/Msg/update + unstyled view builders (pure, universal)
  popover/positioning.gleam  # client-only: Floating UI + dismissal, wired via one `sync` effect
  popover_ffi.ts             # the FFI implementation (TypeScript)
  styled/popover.gleam       # shadcn-styled trigger + panel built on the headless popover
  theme.css                  # design tokens (shadcn model, Tailwind v4, light/dark)
playground/                  # Vite dev playground (mounts the styled components)
test/                        # gleeunit tests for the pure state machines
```

## Universal & FFI

A primitive splits cleanly in two:

- **The headless module is pure Gleam** — no DOM, no FFI — so it compiles on
  every target and is unit-testable in isolation.
- **The effects module holds the DOM/positioning**, talking to [Floating
  UI](https://floating-ui.com) over FFI. Floating UI is JavaScript-only, so each
  binding carries a Gleam fallback body; the package still compiles on Erlang,
  and the fallbacks never run because Lustre effects only execute client-side.

**FFI is written in TypeScript.** Gleam references it with an absolute,
extension-less path:

```gleam
@external(javascript, "/src/gg_ui/popover_ffi", "startPositioning")
fn start_positioning(...) -> Nil { Nil }
```

`gleam build` passes that path through verbatim; Vite (rooted at this package)
resolves `/src/gg_ui/popover_ffi.ts` and transpiles it. Biome formats and lints
the `.ts`; `tsc --noEmit` type-checks it against Floating UI's types — no
separate compile-to-`.mjs` step.

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
gleam test       # state-machine tests
```

## Consuming gg_ui (preview)

While unpublished, the plan is to add it to a host app as a Gleam **path
dependency** and import the styled components. The host imports
`src/gg_ui/theme.css` for the tokens and (for FFI resolution) builds with Vite.
The exact cross-package FFI resolution story is being finalised alongside the
first consumer (a companies selector).

## License

MIT.

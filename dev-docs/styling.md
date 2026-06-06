# Styling

How **shape styles** (nova / vega / luma / sera / lyra / mira / maia) interact
with the headless layer, the per-component recipe, and Tailwind. Companion
doc to [`themes.md`](themes.md), which covers color palettes; this one is
about **shape** (padding, radius, density, the visual identity of each style).

## What a "style" is

A style is shadcn's term for the orthogonal axis to color. Nova is "reduced
padding and margins", luma is "fluid, luminous, soft", lyra is "boxy and
sharp for mono fonts", etc. — pick one of seven looks. A theme picks colors.
Together they define the visual identity.

The same component (`button`, `accordion`, `popover`) renders differently
under each style. Same markup, same behavior, different padding / radius /
spacing / shadow.

## What shadcn v4 changed

Worth flagging because we're following the v4 pattern, not v3.

**v3:** each component's styling was a `cva` recipe in its `.tsx` file —
`bg-primary text-primary-foreground hover:bg-primary/90`, etc. To support a
second style you forked the component file.

**v4:** the component file is thin (`<button data-slot="button"
className="cn-button cn-button-variant-default cn-button-size-default">`) and the
styling lives in **per-component CSS fragments** that target the **class names**
via `@apply`:

```css
/* styles/shapes/nova/button.css */
.style-nova {
  .cn-button { @apply inline-flex shrink-0 items-center justify-center ...; }
  .cn-button-variant-default { @apply bg-primary text-primary-foreground ...; }
  .cn-button-variant-outline { @apply border bg-background ...; }
}
```

> **Note (corrected):** shadcn v4 keys these overlays on **class names**
> (`.cn-button-variant-default`), *not* on `data-variant` attributes — verified
> against `apps/v4/registry/styles/style-nova.css`. Earlier drafts of this doc
> showed `[data-variant="…"]` selectors; that was wrong. The variant/size axes
> are class names; `data-slot` stays as a stable structural hook.

The component file is the same across styles. The CSS fragments are different per
style. Adding a new style is a set of fragments, not a fork of every component.

## How we adopt it — **done** for button + popover

This is the layout the repo ships today: the `gg_base_ui` headless package + a
thin `gg_ui/ui/` + per-component shape fragments under
`gg_ui/styles/shapes/nova/`. The shape that landed:

1. **Thin the Gleam file.** The `gg_ui/ui/<component>.gleam` recipe emits only
   `cn-*` class names — `class="cn-button cn-button-variant-default
   cn-button-size-default"` plus `data-slot="button"`. No raw Tailwind.
2. **The class strings live in per-component fragments.**
   `gg_ui/styles/shapes/<style>/{button,popover}.css` each carry a
   `.cn-button { @apply ... }` block (and one per variant / size). A thin index
   `gg_ui/styles/shapes/<style>.css` `@import`s the fragments. Fragments carry
   **no `@import "tailwindcss"`** — a consumer entry assembles Tailwind + the
   fragments (see below).
3. **Style selection is a class on the app root.** The host app (and Storybook,
   via a `preview.ts` decorator) puts `class="style-nova"` (plus `dark`) on the
   root, and the `.style-nova` cascade activates.

End result: **one thin Gleam file per component, N fragment sets (one per
style)**, instead of N × M Gleam files (one per component-style combination).

### The Gleam recipe stays — but emits class names

`gva` used to carry the *whole* Tailwind string. Now it assembles **`cn-*` class
names** for variant / size; the Tailwind itself lives in
`styles/shapes/nova/button.css`:

```gleam
const base = "cn-button"

pub fn classes(variant variant: Variant, size size: Size) -> String {
  gva.gva(default: base, resolver: resolve, defaults: [])
  |> gva.with(VariantKey(variant))   // resolve → "cn-button-variant-default"
  |> gva.with(SizeKey(size))         // resolve → "cn-button-size-default"
  |> gva.build
  |> fn(recipe) { cn.cn([recipe]) }  // kept for parity; cn-* names don't conflict
}

pub fn button(variant, size, attrs, children) -> Element(msg) {
  base_button.button(
    config: base_button.config(),
    attrs: [
      attribute.attribute("data-slot", "button"),
      attribute.class(classes(variant:, size:)),
      ..attrs
    ],
    children:,
  )
}
```

`classes(variant:, size:) -> String` is also the "ad-hoc render-as" hook
documented in [`composition.md`](composition.md) — it returns the `cn-*` string
for callers styling a non-`<button>` element.

**What this gains us:** changing nova's padding doesn't touch any Gleam file.
A second style (luma) is one CSS file, not a fork. The Gleam compile graph
stays small.

**What we lose:** type-checked class names at *class generation* time. We still
type-check `Variant` and `Size` in Gleam, but the *visual mapping* lives in CSS
— a typo in a `cn-button-variant-*` name won't fail compile. Mitigation: a
single `variant_class(Variant) -> String` function per component, exhaustive
`case`, so the compiler still complains if you add a variant and forget the
mapping.

## File layout — **shipped**

The kit lives in the `gg_ui` package; the headless behavior is a separate
`gg_base_ui` package (imported, never ejected). The shape (Style) axis ships
here; the color axes (Base Color + Theme) are separate fragment trees —
see [`themes.md`](themes.md).

```
packages/gg_base_ui/         ← LAYER 1: headless behavior + a11y (own Hex pkg)
  button/ popover/ positioning/ arrow/

packages/gg_ui/src/gg_ui/
  ui/
    button.gleam             ← thin styled layer (cn-* class names, no Tailwind)
    popover.gleam
  styles/
    tokens.css               ← @theme inline mapping + :root { --radius }
    shapes/
      nova.css               ← thin index: @import "./nova/button.css"; ...
      nova/
        button.css           ← .style-nova { .cn-button { @apply ...; } ... }
        popover.css
      vega.css               ← (future)  vega/{button,popover}.css ...
    base_colors/             ← color axis (neutral palette) — see themes.md
    themes/                  ← color axis (accent override)  — see themes.md
    motion/                  ← motion axis (native :popover-open) — see themes.md
```

`ui/` sits at the top of `src/gg_ui/` (sibling of `styles/`), matching shadcn's
leaf `ui/` + the CLI's `aliases.ui`. The headless layer is no longer a `base/`
sibling — it's the separate `gg_base_ui` package. The old
`styles/base_nova/ui/<name>/<name>` nesting (and its `base_` prefix) is gone:
there's only one headless layer in our world, so "base-" carried no information.
We keep the `style-` prefix on the class name (`.style-nova`) for visual
scoping, matching shadcn's convention.

The fragments carry **no `@import "tailwindcss"`** — a consumer entry pulls in
Tailwind once, then the fragments. Storybook's entry is `src/docs/gg_ui.css` at
the repo root; a real app's entry is assembled by the CLI (later). Nested
`@import` + `@apply` resolve fine through the chain.

Remaining migration work (incremental):

1. ~~Land button in the new layout under nova.~~ ✅
2. ~~Verify Storybook renders, theme tokens resolve.~~ ✅
3. ~~Migrate popover.~~ ✅
4. ~~Split shape into per-component fragments + thin index.~~ ✅
5. Add a second style (vega) — proves the layout actually decouples.
6. Migrate remaining components as they're built.

## The shadcn preset name lives on in config

We started with `styles/base_nova/` to match shadcn's preset naming
(`base-nova`) — "the nova style on top of our base layer". With only one
headless layer (no Radix-vs-Base-UI choice) that prefix was redundant and has
been dropped. The shadcn preset name `base-nova` lives on as the **value of
`components.json.style`**, not as a directory name.

## Style + base-color + theme combinations

Same matrix as shadcn — three orthogonal axes, each toggled by a class on the
root. This doc owns **Style** (shape); the two **color** axes are covered in
[`themes.md`](themes.md):

```
style     ∈ { nova, vega, luma, sera, lyra, mira, maia }              ← shape   (.style-*)
baseColor ∈ { neutral, stone, zinc, mauve, olive, mist, taupe }       ← color   (.base-color-*)
theme     ∈ { amber, blue, cyan, emerald, … 17 accents }             ← accent  (.theme-*, on top of base color)
```

A consuming app picks one of each. The CLI's `init` flow walks the user
through it (or accepts a `--preset base-nova-neutral` shortcut).

Defaults:

```jsonc
{ "style": "base-nova", "tailwind": { "baseColor": "neutral" } }
```

— matches shadcn's defaults too.

## Implementation checklist

- [x] Pick a deterministic mapping from `Variant` / `Size` → `cn-*` class
      names (e.g. `Default → "cn-button-variant-default"`, `IconXs →
      "cn-button-size-icon-xs"`).
- [x] Add a thin `gg_ui/ui/<component>.gleam` per component that emits `data-slot`
      and a `cn-*` class string (`gva` + `cn`).
- [x] Move every class string from the Gleam recipe into per-component shape
      fragments under `styles/shapes/<style>/<component>.css`, indexed by a thin
      `styles/shapes/<style>.css`.
- [x] Keep the `gva` recipe emitting `cn-*` names; keep `classes(...) -> String`
      for callers that need the class string (e.g. ad-hoc render-as).
- [x] Apply `style-nova` on the Storybook root (a `preview.ts` decorator).
      _Future:_ a toolbar control to flip `style-<name>` / `dark` per story.
- [ ] Document the class-name contract in `composition.md` (the `cn-*` selectors
      a style overlay can rely on).

The CSS files themselves are translated from shadcn's `apps/v4/registry/styles/style-<name>.css`.
That's where the visual definition of each style lives upstream — we translate
it (the `@apply`s reference the same `--background` / `--primary` tokens we've
already ported), and they render identically once our themes match. The popover
recipe is adapted to gg_ui's **native-first** anatomy (no `data-open`/`data-closed`
animation classes — visual state comes from `:popover-open`), so it stays
animation-free.

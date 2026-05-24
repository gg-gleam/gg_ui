# Themes & base colors

The color half of the visual identity. **Shape** lives in
[`styling.md`](styling.md); this one is about CSS variables — what the tokens
mean, where they live, how light/dark switches, and how shadcn's `themes.ts`
data file maps onto our per-file CSS fragments.

## Two concepts: theme vs base color

shadcn separates them, and so do we — two orthogonal axes, each toggled by a
class on the root:

- **Base color** — the *neutral* palette that drives most of the UI:
  background, foreground, muted, border, input, plus a sensible **default
  neutral `--primary`**. The "feel" — warm-grey (stone), cool-grey
  (zinc / neutral), almost-purple (mauve), etc. Seven options: `neutral`,
  `stone`, `zinc`, `mauve`, `olive`, `mist`, `taupe`. Lives at
  `styles/base_colors/<name>.css`, scoped to `.base-color-<name>`.
- **Theme** — the *accent* axis. A theme overrides only the primary-family
  tokens (`--primary` / `--primary-foreground`) **on top of** whatever base
  color is active. Seventeen accents: `amber`, `blue`, `cyan`, `emerald`,
  `fuchsia`, `green`, `indigo`, `lime`, `orange`, `pink`, `purple`, `red`,
  `rose`, `sky`, `teal`, `violet`, `yellow`. Lives at
  `styles/themes/<name>.css`, scoped to `.theme-<name>`.

This is shadcn's exact vocabulary — the accent axis is **"Theme"** (shadcn's
`THEMES` / `ThemeName`), never "colors" or "accents".

A base color is enough on its own (it ships a neutral `--primary`). Layering a
theme is optional and only swaps the accent. Because theme files are imported
**after** base colors and target the same `--primary`/`--primary-foreground`,
the accent wins by source order — no specificity tricks.

## What lives where

Both axes are **CSS fragments**: pure CSS with **no `@import "tailwindcss"`**.
They ship in the `gg_ui` package and are stitched together by a consumer entry
(Storybook's `src/docs/gg_ui.css`; the CLI-assembled entry in a real app later).

```
packages/gg_ui/src/gg_ui/styles/
  tokens.css                ← shared @theme inline mapping + :root { --radius }
  base_colors/
    neutral.css             ← .base-color-neutral { … } + .dark variant
    stone.css   zinc.css   mauve.css
    olive.css   mist.css   taupe.css
  themes/
    blue.css                ← .theme-blue { --primary; --primary-foreground } + .dark
    amber.css   cyan.css   emerald.css   …   yellow.css   (17 total)
```

The consumer entry imports `tailwindcss`, then `tokens.css`, then all the
base-color fragments, then all the theme fragments (so accents win), then the
shape fragments. Nested `@import` resolves fine through the chain. The active
combination is selected by classes on the document root, exactly like dark mode:

```html
<html class="base-color-neutral theme-blue dark">
```

`base-color-*` is required; `theme-*` is optional; `dark` is a third orthogonal
axis (below).

## Token shape

The token set is taken verbatim from shadcn. The **base color** fragment sets
the full neutral token surface:

```
--background        --primary         --destructive
--foreground        --primary-foreground
--card              --secondary       --border
--card-foreground   --secondary-foreground   --input
--popover           --muted           --ring
--popover-foreground   --muted-foreground
--accent            --chart-1 ... --chart-5
--accent-foreground   --sidebar         --sidebar-foreground
--radius            --sidebar-primary  --sidebar-primary-foreground
                    --sidebar-accent   --sidebar-accent-foreground
                    --sidebar-border   --sidebar-ring
```

A **theme** fragment overrides only `--primary` and `--primary-foreground` —
nothing else. (shadcn's accents don't set `--ring`; neither do we.)

Values are OKLCH (Tailwind v4's preference), light/dark pairs, exact same
numbers as `apps/v4/registry/themes.ts` in shadcn.

We don't invent tokens. If shadcn doesn't have a token for it, we don't
either — and components that need a not-yet-tokenised value (e.g. a
component-specific shadow) hardcode it for now and lobby upstream to add
the token if it's worth promoting.

## Light / dark

Same model as shadcn — each base-color and theme fragment ships **both** light
and `.dark` values. Light values sit at the axis class; dark values sit at the
axis class crossed with `.dark`:

```css
.base-color-neutral {
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  /* ... light values ... */
}

.dark .base-color-neutral,
.base-color-neutral.dark {
  --background: oklch(0.145 0 0);
  --foreground: oklch(0.985 0 0);
  /* ... dark values ... */
}
```

Theme fragments mirror the shape for their two tokens:

```css
.theme-blue {
  --primary: oklch(0.488 0.243 264.376);
  --primary-foreground: oklch(0.97 0.014 254.604);
}

.dark .theme-blue,
.theme-blue.dark {
  --primary: oklch(0.424 0.199 265.638);
  --primary-foreground: oklch(0.97 0.014 254.604);
}
```

Dark mode is a separate axis, applied by toggling `.dark` on any ancestor
(or on the axis element itself). The entry declares the `@custom-variant dark`
matcher; the fragments inherit it.

## `@theme inline`

Tailwind v4 needs the tokens republished as theme tokens so utilities like
`bg-background` resolve. This mapping is **shared**, not per-file — it lives once
in `styles/tokens.css`:

```css
@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-primary: var(--primary);
  /* ... */
}
```

The indirection (`--color-background → --background`) is what makes
`bg-background` produce `background-color: var(--color-background)`, which in
turn resolves to whatever the active `.base-color-*` (and `.theme-*`) set
`--background` / `--primary` to. shadcn does this; we do this; don't change it.

## Chart-color override

shadcn lets a theme pick a different palette for `--chart-1..5` than its own
accent colors. Example: a `neutral` base color but with `blue`'s chart colors.
In our `components.json` that's `chartColor: "blue"` (deferred — we'll add when
we have the first chart component to test it against).

For now the chart tokens come from the base color and the theme axis only
touches `--primary` / `--primary-foreground`. The CLI override comes later.

## Radius

`--radius` is shared, not per-color. It lives at `:root` in `styles/tokens.css`
(currently `0.625rem`) because the radius scale below it is derived via
`@theme inline` (`calc(var(--radius) - 2px)`, …) and that calc must resolve at
`:root` — if `--radius` were only defined under `.base-color-*`, the scale would
compute to *invalid* and utilities like `rounded-[min(var(--radius-md),10px)]`
would collapse to a 0 radius. All base colors ship the same value, so a single
root definition is lossless. A future `radius` field in `components.json` lets
users override per-project.

## How a theme item is described in the registry

A `registry:theme` JSON item is just CSS vars, no files:

```jsonc
{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "theme-blue",
  "type": "registry:theme",
  "cssVars": {
    "light": {
      "primary": "oklch(0.488 0.243 264.376)",
      "primary-foreground": "oklch(0.97 0.014 254.604)"
    },
    "dark": { ... }
  }
}
```

When the CLI installs a base color or theme, it:

1. Writes/updates the corresponding fragment in the consuming app (the file the
   CLI maintains under whatever path `tailwind.css` points to, *or* a sibling
   to it under `aliases.lib` — TBD, see open questions).
2. Adds the `@import` for it to the user's main CSS file if not already present
   (base colors before themes).
3. If `cssVariables: true` in `components.json`, the vars are inlined as above.
   Otherwise (`false`), the CLI emits utility-class-friendly raw colors — we
   still don't recommend this mode.

## Open questions

- **Where do the color CSS files land in the consumer app?** shadcn writes them
  inline into the user's `globals.css`. We have two options: (a) inline same as
  shadcn — simple, one file to read; (b) write per-axis CSS files under
  `<aliases.lib>/styles/base_colors/<name>.css` and `themes/<name>.css` and
  `@import` them. Tentative pick: **(a)** for parity, **(b)** if the user opts in
  via a flag. Decide when implementing the CLI.
- **`radius` per project.** Either a CLI flag or a top-level `components.json`
  field. shadcn went CLI flag; we copy that until anyone asks for a config field.
- **More base colors / themes than shadcn?** Tempting. We resist until the
  current set is all good and we hear demand. Adding a custom one is just a new
  CSS fragment anyway — users who need one can write it without us shipping every
  variant.

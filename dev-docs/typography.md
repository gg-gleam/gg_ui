# Typography

What shadcn does about text, and how it maps to `gg_ui`. Companion to
[`styling.md`](styling.md) (shape) and [`themes.md`](themes.md) (color); this
one is about **type** — the font axis, the per-element recipes, the shared text
scale that component internals draw from.

> **Status: implemented (font plumbing + recipe catalogue).** The library
> exposes the **`--font-sans` / `--font-heading` / `--font-mono`** custom props
> (seeded with system-stack fallbacks in `tokens.css`, republished via
> `@theme inline` as the `font-sans` / `font-heading` / `font-mono` utilities) —
> and nothing more. **Font *family* selection is a consumer concern**, matching
> shadcn (font isn't a library-prescribed axis — see below): the **Storybook app**
> loads real variable families (`@fontsource-variable/*`) and its **Font** +
> **Heading** toolbars set those vars (independent body/heading, shadcn's split).
> The recipes ship the shadcn way — **as a documentation story, not a component**
> (`Components/Typography`: Overview / Elements / Roles). No
> `gg_ui/ui/typography.gleam` exists, by design (see the decision below). Still
> deferred: wiring the semantic **roles** into real component internals (none
> beyond `button`/`popover` yet), and RTL.

## The core philosophy: shadcn ships *no* typography

The single most important line on shadcn's Typography page:

> *We do not ship any typography styles by default. This page is an example of
> how you can use utility classes to style your text.*

There is **no `<Typography>` component**, no `prose` wrapper, no global
`@apply` on bare `h1`/`p`. shadcn's typography is a **documentation page of
copy-paste recipes**, not code you install. This is deliberate and it is the
opposite of `@tailwindcss/typography`'s `prose` (a black-box that restyles a
whole subtree):

- **The consumer owns their text.** Bare HTML elements stay unstyled so app
  content, prose from a CMS, and design-system surfaces don't fight a global
  cascade. You opt *in* per element, never opt *out* of a global.
- **Recipes, not abstractions.** Each "style" is just a string of Tailwind
  utilities on a native element. Nothing to import, nothing to theme around,
  trivially overridable — same authoring model as the rest of shadcn (the
  component file is thin; the value is the recipe).
- **No subtree magic.** `prose`-style descendant selectors make "why is my
  text styled" un-greppable. shadcn keeps every decision on the element that
  carries it.

**For `gg_ui` this is a gift:** typography is pure markup + CSS, no behavior, no
FFI — so it satisfies the universal/both-targets rule (rule 3) by construction
and never touches `gg_base_ui`. There is no headless layer for type. The only
real design work is the *font axis* and *whether/how we package the recipes*.

## How shadcn organizes it

Two distinct buckets — keep them separate, they answer different questions:

### 1. Element recipes — "how do I style an `<h2>`?"

A catalogue keyed by **HTML element**, each a utility string on the native tag:

| Element | Recipe (Tailwind) | Notes |
| --- | --- | --- |
| `h1` | `scroll-m-20 text-4xl font-extrabold tracking-tight text-balance` | `text-balance` on the page title only |
| `h2` | `scroll-m-20 border-b pb-2 text-3xl font-semibold tracking-tight first:mt-0` | section rule via `border-b`; `first:mt-0` kills leading gap |
| `h3` | `scroll-m-20 text-2xl font-semibold tracking-tight` | |
| `h4` | `scroll-m-20 text-xl font-semibold tracking-tight` | |
| `p` | `leading-7 [&:not(:first-child)]:mt-6` | rhythm via *top* margin, guarded |
| `blockquote` | `mt-6 border-l-2 pl-6 italic` | |
| `ul` | `my-6 ml-6 list-disc [&>li]:mt-2` | item spacing on the list, not the `li` |
| `table` | `w-full` in an `overflow-y-auto` wrapper; cells `border px-4 py-2`, rows `even:bg-muted` | zebra via `even:` |
| inline `code` | `relative rounded bg-muted px-[0.3rem] py-[0.2rem] font-mono text-sm font-semibold` | |
| link | `font-medium text-primary underline underline-offset-4` | uses `--primary`, not a hardcoded color |

### 2. Semantic text roles — "I need de-emphasized helper text"

Intent-named, **element-agnostic** — the same vocabulary component internals
reuse (see below):

| Role | Recipe | Typical use |
| --- | --- | --- |
| **Lead** | `text-xl text-muted-foreground` | intro paragraph under a title |
| **Large** | `text-lg font-semibold` | emphatic standalone line (e.g. a dialog title) |
| **Small** | `text-sm leading-none font-medium` | labels |
| **Muted** | `text-sm text-muted-foreground` | helper / description text |

### The idioms worth internalizing

These recur across every recipe and are the actual "lessons":

1. **Vertical rhythm lives on *top* margins, guarded.** `p` uses
   `[&:not(:first-child)]:mt-6`; `h2` uses `first:mt-0`. Spacing is owned by the
   *following* element and suppressed when it's first, so a block never carries
   a spurious leading gap and there's no margin-collapse guessing. (This is the
   one place shadcn reaches for a descendant-ish selector — and it's still on
   the element itself, not a `prose` ancestor.)
2. **Tightened headings.** `tracking-tight` on every heading; weight escalates
   `font-extrabold` (h1) → `font-semibold` (h2–h4).
3. **`scroll-m-20` on every heading** so in-page anchor jumps don't hide the
   heading under a sticky header. Cheap, easy to forget.
4. **`text-balance` on the title** only — even line lengths matter most for the
   biggest type; not worth it (or correct) for body.
5. **Color is a token, never a literal.** Secondary text is
   `text-muted-foreground`; links are `text-primary`. Typography rides the
   **Base Color / Theme** axes ([`themes.md`](themes.md)) for free — dark mode
   and accent swaps just work.
6. **Spacing on the container, not the leaf.** List item gaps are `[&>li]:mt-2`
   on the `ul`; table zebra is `even:bg-muted` on the row. The leaf stays dumb.

## The font axis — the part that *is* a system

Separate from the recipes, shadcn treats **font** as a first-class axis of a
design system, alongside Style / Base Color / Theme. The create flow exposes
**two** independent selectors — body (`font`) and heading (`fontHeading`) — over
a curated list (Geist, Inter, Playfair Display, …) tagged `sans | serif | mono`.

Mechanically it's three CSS variables republished through Tailwind's
`@theme inline`, so `font-sans` / `font-heading` / `font-mono` become real
utilities:

```css
@theme inline {
  --font-sans: var(--font-sans);
  --font-heading: var(--font-heading);
  --font-mono: var(--font-mono);
}
```

- Body text inherits `--font-sans` (applied once at the root).
- Headings opt into `--font-heading` via a `font-heading` utility (or
  `cn-font-heading` class) — and `--font-heading` *defaults to inherit*, so a
  one-font system needs no second choice.
- A **style** can override the heading treatment entirely: the `sera` style
  remaps `font-heading` to a serif and adds
  `text-lg font-semibold tracking-wider uppercase`. Font is an axis, but the
  *shape* axis still gets to reinterpret it.
- Some styles even rescale the whole type ramp by overriding the `--text-*`
  steps (`--text-xl: 1.1rem`, …) and base size — proof the scale is tokenized,
  not hardcoded in recipes.

## How component internals reuse the scale

The semantic roles aren't just for docs — **component parts are built from the
same vocabulary**, which is what keeps the system coherent:

- `DialogTitle` ≈ **Large** (`text-lg font-semibold`)
- `DialogDescription` ≈ **Muted** (`text-sm text-muted-foreground`)
- `FieldLabel` ≈ **Small** (`text-sm … font-medium`)

So "typography" and "components" aren't separate systems — the four roles are
the shared text scale, and a component is just markup that happens to pick the
right role. Get the roles right and component text falls out for free.

## RTL

Typography is the canonical RTL surface: logical properties (`ms-*`/`me-*`,
`ps-*`/`pe-*`, `border-s/e`) and `dir`-aware layout, plus `text-balance`/`pretty`
work regardless of direction. Nothing direction-specific is baked into the
recipes themselves — they rely on Tailwind's logical-property utilities and the
document `dir`.

## How we adopt it in `gg_ui` — what shipped

Following shadcn's restraint, **we do not ship a typography component.** Two
pieces, mapped onto the existing architecture:

### 1. Font plumbing in the library; family selection in the consumer (**done**)

shadcn has **no "font axis"** of CSS classes: it picks a real family at create
time, installs it, and writes the `--font-*` vars (`font` isn't even a
`components.json` field — it's a scaffold-time choice, unlike `iconLibrary`,
which *is* persisted). We mirror that split:

- **Library = the var contract only.** `styles/tokens.css` seeds `--font-sans` /
  `--font-heading` / `--font-mono` at `:root` with **system-stack fallbacks**
  (`--font-heading` defaults to the body face) and republishes them via
  `@theme inline` (`--font-sans: var(--font-sans)`, …) so `font-sans` /
  `font-heading` / `font-mono` are real utilities. `inline` means Tailwind emits
  no `--font-*` of its own, which is why the `:root` seed is load-bearing — same
  reasoning as the `--radius` note in that file. **The library bundles no font
  files and prescribes no families.** (An earlier draft shipped `.font-set-*`
  fragments under `styles/fonts/`; that was an abstract stand-in and was removed
  — it isn't how shadcn models fonts.)
- **Consumer = real families + the picker.** The Storybook app
  (`.storybook/fonts.ts`) loads a curated cross-section of variable faces via
  **`@fontsource-variable/*`** (the same packages shadcn's create flow installs:
  Geist, Inter, DM Sans, Figtree, Space Grotesk, Playfair Display, Lora,
  JetBrains Mono, Geist Mono). Two toolbars — **Font** (body) and **Heading**
  (independent; `Inherit` follows the body) — and the `preview.ts` decorator sets
  `--font-sans` / `--font-heading` from the picked families (a `System` body pick
  leaves the `:root` fallback). This is shadcn's body/heading font-family picker,
  not an abstract "type set". Headings opt into `--font-heading` via the
  `font-heading` utility in the recipes.

The library side is pure CSS → both targets, no `gg_base_ui` involvement.

### 2. The recipes — docs-only, **option (a)** (**done**)

We ship the recipes as a **Storybook documentation story**
(`apps/storybook/src/stories/typography/`: Overview / Elements / Roles), **not**
as a `gg_ui/ui/` component. The story `.gleam` uses raw Tailwind utility strings
directly — legitimate because stories live in the consumer app (which imports
Tailwind), and consistent with how existing stories use utilities for layout.
This is maximal fidelity to shadcn's "we ship nothing," and it keeps the kit's
"no raw Tailwind in `gg_ui/ui/`" rule intact precisely *because* typography never
enters the kit.

**Decision: (a) over (b).** The rejected alternative (b) was `cn-*` recipes in a
fragment (`.cn-h1 { @apply … }`) plus `typography.h1()` helpers emitting `cn-h1`.
It's more "batteries included" but re-introduces the global-ish styled-prose
surface shadcn deliberately avoids, and shadcn ships nothing of the sort. We
escalate to (b) only if a consumer needs a *stable* styled-prose surface (e.g. a
docs renderer) — at which point the recipes here port over verbatim.

The **semantic roles** (Lead / Large / Small / Muted) are demonstrated in the
`Roles` story as the shared scale; wiring them into real component internals
(`dialog`/`field`/`card`) happens when those components land.

## Open questions

- **How big is the family catalogue, and how does a real app register a font?**
  The Storybook demo loads 9 families (shadcn curates ~26). The demo's loading is
  `@fontsource` imports, which is a *demo* choice — a CLI-scaffolded app would get
  the same `--font-*` vars written for it plus a font dependency / `@font-face` of
  its choosing (shadcn writes `next/font` or `@fontsource`). Formalizing the
  catalogue + how the CLI installs a chosen family is a CLI concern
  ([`cli.md`](cli.md)); the library contract (the three vars) is fixed.
- **A font "preset" layer?** shadcn pairs a style with an icon library *and* a
  font/heading combination per preset (e.g. `sera` → Lucide / Noto Sans +
  Playfair Display). We have the mechanism but no preset bundling. Likely lands
  with the CLI alongside icon-library prescription.
- **Where do the semantic roles live once components need them?** Re-demonstrated
  as raw utilities per component, or hoisted into shared `cn-*`/helpers. Decide
  when the first text-heavy component (`dialog`/`field`/`card`) lands — that's
  also the trigger to revisit (a) vs (b).
- **RTL.** shadcn has an RTL typography example; we haven't added a `dir="rtl"`
  story or audited the recipes for logical-property correctness yet. Deferred.

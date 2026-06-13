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
> Instead of shadcn's copy-paste recipes, we ship a real, typed **`text`
> component** (`gg_ui/ui/text.gleam`, story `Components/Text`) — a considered
> divergence justified by Lustre ergonomics + enforcement (see §2). Markdown/MDX
> is out of scope (style it with Tailwind `prose`). Still deferred: per-shape
> `text.css` beyond `nova`, and RTL.

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
  (`.storybook/fonts.ts`) loads a curated cross-section of variable faces
  (Geist, Inter, DM Sans, Figtree, Space Grotesk, Playfair Display, Lora,
  JetBrains Mono, Geist Mono). Two toolbars — **Font** (body) and **Heading**
  (independent; `Inherit` follows the body) — and the `preview.ts` decorator sets
  `--font-sans` / `--font-heading` from the picked families (a `System` body pick
  leaves the `:root` fallback). This is shadcn's body/heading font-family picker,
  not an abstract "type set". Headings opt into `--font-heading` via the
  `font-heading` utility in the recipes.

  > **On the loading mechanism (don't over-read it):** we self-host via
  > `@fontsource-variable/*`. shadcn's *docs site* does **not** — it's a Next app
  > and loads preview fonts with `next/font/google`; its `@fontsource` package
  > names are only a metadata field + one non-Next starter template, and its
  > generated setup tells users to use `next/font` or Google Fonts. We're a
  > Vite/Storybook app (no `next/font`) and want the vitest-browser run offline,
  > so `@fontsource` self-hosting is the right fit — but it's a *demo* choice, not
  > a library contract. A CLI-scaffolded app would get the `--font-*` vars written
  > for it and pick its own loader.

The library side is pure CSS → both targets, no `gg_base_ui` involvement.

> **On the recipes (not shipped).** An earlier iteration shipped the shadcn
> recipes as a docs-only `Components/Typography` Storybook story; it was
> **removed** once `text` (below) landed. `text` covers authored app views, and
> **Markdown/MDX is out of scope** (style it with Tailwind's `prose` plugin), so
> the recipe page had no remaining job. The shadcn recipes still live in this doc
> above ("How shadcn organizes it") as rationale + the source of the scale values
> `text` encodes.

### 2. A `text` component — a considered divergence from shadcn

shadcn ships *no* Text component; gg_ui's `gg_ui/ui/text.gleam` **does**. This is
a deliberate divergence, justified by the platform:

- **Lustre ergonomics flip shadcn's reasoning #3.** In JSX a recipe is just
  `className="text-4xl font-extrabold tracking-tight"`; in Gleam it's
  `html.h1([attribute.class("…long string…")], …)` — untyped, easy to typo. A
  typed `text.h1(attrs, children)` earns its keep here in a way it
  doesn't in shadcn-React.
- **The API mirrors Lustre — `text.h1(attrs, children)`, enforced in the type
  system.** Like every Lustre element (`html.h1(attrs, children)`), a helper
  takes a `List(Attr(msg))` then children; the common case is an empty list. We
  chose this over a `Props` *record* (briefly tried) because it's the ecosystem
  idiom — `lustre/attribute` and every element work this way — and it has the
  least boilerplate (no `text.props()` / no `Props(..props(), …)` record-update,
  which Gleam's lack of default args makes verbose):
  ```gleam
  text.h1([], [html.text("Heading")])                          // defaults
  text.h1([text.color(text.Muted), text.align(text.Center)], […])
  ```
  `Attr` is **opaque** with deliberately **no `class`/`style` constructor**, so
  off-token / off-scale text *can't be expressed* — the guarantee a recipe page
  can only suggest, and why it needs **no tailwind-merge** (no external class
  sources). `text.color(Muted)` *is* the idiomatic "named key" in Gleam.

Shape of it:

- **A closed, *numeric* `Style` scale** — `h1 … h7` (the way a designer names a
  text style in Figma: "set h5, it maps to the DS"; semantic names like
  `Body`/`Large`/`Lead` were "harder to remember what to apply"). Each member
  bundles size + weight + leading + tracking + family as *one* decision. **Weight
  variants are baked enum members** — `H4M` (medium), `H4B` (bold), `H5M`, `H6M`,
  `H6B` — a *curated allow-list* with the terse `h4_m`/`h4_b` helper convention
  from the Latitude `Text`. We **rejected a `weight()` modifier**: it would permit
  off-scale combos (h1 + thin) and need override machinery, whereas baked members
  only allow sanctioned styles (stronger enforcement, 1:1 with named Figma
  styles, simpler CSS). Element default: `h1–h4` → `<h1>–<h4>`; `h5–h7` → neutral
  `<p>` (a body-sized `<h6>` would pollute the a11y outline).
- **Tokenized modifiers, every one a closed enum, all `Attr` constructors.** The
  Latitude `Text` prop set — but typed: `color` (default `Foreground`), `align`,
  `transform`, `decoration`, `italic`, `truncate` (`Ellipsis` | `Lines(n)`, n
  clamped 1–6), `whitespace`, `word_break`, `wrap` (balance/pretty), `opacity`,
  `selectable`. Omit the `Attr` ⇒ that class isn't emitted.
- **`render_as` + a11y/events live in the same list — no raw `class` anywhere.**
  `text.render_as(html.h3)` renders the style on a *different*, real Lustre
  element (the asChild / `useRender` analogue) — so an H1 *look* on a semantic
  `<h3>` is `text.h1([text.render_as(html.h3)], …)`, no `import html` + merge
  dance, and never the Latitude `Text.H1`-renders-`<span>` footgun. `text.id` /
  `text.aria` / `text.data` / `text.on_click` cover a11y + interaction. All are
  the same opaque `Attr`, none can carry `class`.
- **No headless layer.** Text has no behavior/ARIA beyond the element, so (like
  `icon`) it lives only in `gg_ui/ui/`. Emits `cn-text-*`. Split, like the rest
  of the kit: the **type scale + color** (shape-specific) lives per-shape in
  `styles/shapes/<style>/text.css` (only `nova` so far); the **modifiers**
  (shape-invariant) live in a universal `styles/text.css` (like `icons.css`).
  Story: `Components/Text` — a kitchen-sink `Playground` (every axis a control)
  plus `Scale` / `Colors` / `AsElement` showcases.

**Status: spike.** Open points: whether the curated `Attr` set needs typed
**events** (currently id/aria/data only — events go through the escape hatch);
and the per-shape `text.css` for the other six shapes (the universal modifier
recipes already cover all shapes).

## Two philosophies, side by side

The `text` component is where gg_ui **deliberately parts ways with shadcn**. Both
are internally consistent; they optimize for different distribution models, so
the right choice flips with the platform. The whole rest of this doc is the
argument for the right-hand column.

| | **shadcn** (React, copy-paste registry) | **gg_ui** (Lustre, typed kit) |
| --- | --- | --- |
| **Ships a typography component?** | **No.** Typography is a docs page of utility-class recipes. | **Yes** — `gg_ui/ui/text.gleam`, a real typed component. |
| **Core principle** | *Recipes, not abstractions.* You own the markup + classes. | *Enforcement, not documentation.* The API can't express off-token/off-scale text. |
| **How you style an h1** | `<h1 className="scroll-m-20 text-4xl font-extrabold …">` — a string you copy. | `text.h1([], […])` — mirrors Lustre's `html.h1(attrs, children)`; the recipe lives in a `cn-*` fragment. |
| **The scale** | Open: any Tailwind utilities, any combination. | Closed numeric `h1…h7` enum + curated baked weight members (`h4_m`/`h4_b`). |
| **Off-scale text** | Possible by design (you can write anything). | Impossible to express — the opaque `Attr` has no `class`/`style` constructor. |
| **Color / modifiers** | Raw utilities (`text-muted-foreground`, `uppercase`, `line-clamp-2`). | Tokenized `Attr`s (`text.color(Muted)`, `text.transform(Uppercase)`, `text.truncate(Lines(2))`). |
| **tailwind-merge** | Needed (many class sources can conflict). | **None** — `cn-*` names never conflict; pure join, dual-target. |
| **Element vs style** | The recipe is applied to whatever element you write. | Decoupled: helpers default a tag (h1–h4 headings, h5–h7 `<p>`); `text.render_as(html.h3)` puts any style on any element. |
| **Escape valves** | n/a — it's all open. | `text.render_as` (element) + `text.id`/`aria`/`data`/`on_click` (a11y/events) — same opaque `Attr` list; none can carry `class`. |
| **Why this fits** | A *public registry you copy and own* → transparency > consistency; no abstraction to fight. | A *kit consumed as typed Gleam* → consistency > transparency; utility-string juggling is awkward and a closed API guarantees the scale. |

**Why the divergence is justified here, not a betrayal of shadcn:** two of
shadcn's reasons for *not* shipping a component weaken on Lustre — hand-writing
utility strings on `html.h1` is genuinely worse than JSX `className` (so the
abstraction earns its keep), and the recipes are not trivial to apply by hand. We
keep shadcn's foundations (token-driven color via the Base Color / Theme axes,
the `cn-*` + per-shape-fragment authoring model, ejectability) and only swap the
*surface*: a typed component instead of a recipe page. The Latitude `Text` atom
(the user's own prior art) sat at the far end of this axis — we took its
ergonomics but dropped its `className` hole, its `<span>`-as-`H1` footgun, and
its open `size`/`weight` axes, all of which leaked the consistency a design
system is supposed to enforce.

## Open questions

- **How big is the family catalogue, and how does a real app register a font?**
  The Storybook demo loads 9 families (shadcn curates ~26). The demo's loading is
  `@fontsource` imports, which is a *demo* choice — a CLI-scaffolded app would get
  the same `--font-*` vars written for it and pick its own loader (shadcn's own
  generated setup uses `next/font/google`, or Google Fonts for non-Next apps).
  Formalizing the catalogue + how the CLI installs a chosen family is a CLI
  concern ([`cli.md`](cli.md)); the library contract (the three vars) is fixed.
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

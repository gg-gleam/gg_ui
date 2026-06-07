# Icons

How a consuming Gleam project gets icons, how registry source stays
icon-set-agnostic, and how the (future) CLI rewrites placeholders at
`gg-ui add` time.

The model copies **shadcn's ergonomics** (a placeholder in source + a
transformer at install time) but inverts shadcn's **source of truth**: where
shadcn re-exports SVG from npm packages it doesn't own, we **bake the SVG into
Gleam** so it works on both Lustre targets. The icon geometry lives in
**per-set Hex packages we own** (`gg_icons_lucide`, `gg_icons_tabler`, …),
each with its own **pure-Gleam generator**, all conforming to one shared
interface so any set is consumed identically.

**Variants are first-class.** A *set* (lucide, tabler, …) is a family of one or
more *variants* — a variant is a single rendering style with its own geometry
(stroke vs fill), `viewBox`, and defaults: tabler ships `outline` + `filled`,
heroicons `outline`/`solid`/`mini`/`micro`, phosphor six weights. lucide is the
degenerate case: one variant. The whole system is designed around `(set,
variant)`; a single-variant set is just `variant_count == 1`. See
[Variants](#variants--first-class).

## The constraint that decides everything

Lustre compiles to JS *and* to Erlang. A server component running Lustre on the
BEAM cannot `import "lucide-react"`. Even a JS-only project consuming icons via
FFI is awkward — you'd ship a React-flavoured tree-shaken bundle for nothing.

**So an icon is a Gleam function that emits a Lustre SVG element, with the path
data baked in as string constants.** One function per icon. Zero npm runtime.
Works on JS, works on the BEAM, tree-shakes per function (Gleam's unused-export
elimination). This is the same shape as
[`dinkelspiel/lucide_lustre`](https://github.com/dinkelspiel/lucide_lustre) — we
adopt its *generator* idea, not the package.

```gleam
// generated: gg_icons_lucide/src/gg_icons_lucide/lucide/c.gleam  (shard "c")
pub fn chevron_down(attrs: List(Attribute(msg))) -> Element(msg) {
  icon.svg(                          // shared wrapper from the interface package
    view_box: "0 0 24 24",
    defaults: lucide_defaults,       // fill=none stroke=currentColor stroke-width=2 …
    attrs: attrs,                    // caller attrs come LAST → they win by source order
    children: [svg.path([attribute.attribute("d", "m6 9 6 6 6-6")])],
  )
}
```

## How shadcn does it (for reference)

Four parts — and the key fact is that **shadcn never owns icon geometry**; it
lives in whichever npm package you chose.

1. **`<IconPlaceholder>`** — a component in **registry source** with one prop per
   supported library: `<IconPlaceholder lucide="ChevronDown" tabler="IconChevronDown"
   hugeicons="ArrowDown01Icon" className="size-4" />`. It is **not in the user's
   final code** (see #3).
2. **`iconLibraries` table** (`packages/shadcn/src/icons/libraries.ts`) — per
   library: which npm packages to install, the `import` line, and a `usage`
   template. Each library renders differently (`<ICON/>` for lucide,
   `<HugeiconsIcon icon={ICON} strokeWidth={2}/>` for hugeicons) — which is why
   they can't be unified into one renderer.
3. **`transformIcons`** (`transform-icons.ts`) — a `ts-morph` AST pass that runs
   at `shadcn add`. Reads `components.json → iconLibrary`, finds every
   `<IconPlaceholder>`, keeps the prop for the chosen library, rewrites the
   element via that library's `usage` template, strips the other props + the
   placeholder import, and adds the real `import { ChevronDown } from
   "lucide-react"`. **After this pass the placeholder is gone** — the file on
   disk imports the concrete library. One-time rewrite, zero runtime cost.
4. **The docs-site loader** — a *runtime* re-implementation of `IconPlaceholder`
   (`create-icon-loader.tsx`, `lazy`/`Suspense`, reads a search param) that
   powers the "preview in lucide / tabler / phosphor" toggle on ui.shadcn.com.
   **Docs-only; never shipped to user code.**

> **So what is the placeholder *for*?** Two roles, same name: (a) the
> authoring-time indirection in **registry source** that the transformer
> compiles away, and (b) a **docs preview** shim. The user's installed code
> contains neither — only the concrete icon call.

`apps/v4/scripts/build-icons.ts` scans registry source for placeholder usage and
generates `__lucide__.ts` etc. — but those are just **re-exports**
(`export { ChevronDown } from "lucide-react"`). The real SVG resolves from npm at
runtime. **We cannot do that** (rule 3), so our generator bakes the SVG in.

### shadcn icon **sizes** — there is no scale (the useful finding)

shadcn has **no semantic icon size scale** and **no size prop on icons**. Two
idioms only, both pure CSS:

- **Container default that yields to an override:**
  `[&_svg:not([class*='size-'])]:size-4` — *"if the icon carries no `size-*`
  class, default it to 16px; if it does, the icon wins."* This **already ships in
  `gg_ui`** — every button recipe carries it (`styles/shapes/*/button.css`),
  with `size-3`/`size-3.5` on smaller button sizes.
- **Raw Tailwind on the icon otherwise:** `size-4` (16px) dominates by a
  landslide; then `size-3 / 3.5 / 5 / 6`; `size-8 / 10 / 16` for avatars and
  empty-states. No `sm`/`md`/`lg`.

**Consequence for us:** don't fight this. The default-with-escape-hatch is the
contract; a typed named scale is an optional ergonomic on top, and **its class
names must contain the `size-` token** so they defeat the existing
`:not([class*='size-'])` container default.

## Our architecture — core in the monorepo, sets as their own repos

JS has a different maintainer per icon library on npm. Gleam/Lustre is smaller —
that's the **opportunity**: one unified way to consume any icon set. The split is
**core vs. data**:

- **Core** (`gg_icon` interface + `gg_icon_gen` engine) lives in the **gg_ui
  monorepo** under `packages/`, beside `gg_base_ui` and `gg_ui` — small, tightly
  coupled to the kit, co-released, each still an **independently published Hex
  package** (exactly how `gg_base_ui`/`gg_ui` already coexist). `gg_ui` path-deps
  `gg_icon` like it path-deps `gg_base_ui`.
- **Data** (`gg_icons_lucide`, `gg_icons_tabler`, …) stays in **separate repos**
  under the `gg-gleam` org — thousands of generated files, and
  community-extensible (anyone can publish a `gg_icons_<set>`). Keeping generated
  geometry out of the core monorepo is the whole point.

```
gg_ui monorepo (packages/)              separate per-set repos
  gg_base_ui                              gg_icons_lucide   <variant>/<shard>.gleam
  gg_ui ──path-dep──▶ gg_icon             gg_icons_tabler   modules (geometry baked in)
  gg_icon   INTERFACE: Size, icon.svg(),       │  │
            placeholder (fallback box)         │  │ depend on (Hex)
  gg_icon_gen  ENGINE (dev tool) ◀─dev-dep─────┘  │
  apps/storybook                                  │
                                                  ▼
  gg_ui registry ──references──▶ gg_icons_*   (METADATA only, not a Gleam import)
```

| Package | Kind | Where |
| --- | --- | --- |
| `gg_icon` | interface (Hex) | `gg_ui/packages/gg_icon` |
| `gg_icon_gen` | generator engine (Hex, dev tool) | `gg_ui/packages/gg_icon_gen` |
| `gg_icons_lucide` | set (Hex), repo `gg-gleam/gg_icons_lucide` | `gg_family/gg_icons/lucide` |
| `gg_icons_tabler` | set (Hex), repo `gg-gleam/gg_icons_tabler` | `gg_family/gg_icons/tabler` |

Set repos depend on the **published** `gg_icon` (+ dev-dep `gg_icon_gen`); for
local dev before publish they path-dep into the monorepo
(`gg_icon = { path = "../../gg_ui/packages/gg_icon" }`). That local-dep tax is the
only cost of the core/data split.

**No dependency cycle.** A set imports `gg_icon`; `gg_ui` imports `gg_icon`;
`gg_ui` the *package* never imports a set. The `gg_ui` **registry** *references*
set packages, but that's JSON metadata, not a Gleam import. Acyclic. Anyone can
add a new set later — a `gg_icons_<set>` that depends on `gg_icon` and uses
`gg_icon_gen` is automatically registry-compatible.

### Why a slim `gg_icon` interface package (not "depend on `gg_ui`")

The original sketch had set packages depend on `gg_ui`. That works and compiles,
but it pulls the **entire styled kit** (Tailwind-emitting code, its release
cadence) into what should be a lean, pure-Gleam geometry package. Cleaner: a
tiny **`gg_icon`** package holding only the *interface* —

- `pub type Size { Sm Md Lg … }` and `pub fn size(Size) -> Attribute(msg)`
  (returns `attribute.class("cn-icon-size-md")` — note the `size-` token).
- `pub fn svg(view_box:, defaults:, attrs:, children:) -> Element(msg)` — the
  shared wrapper every generated icon calls. **Generic over `view_box` + default
  attrs because variants demand it**: tabler's `filled` needs `fill=currentColor`
  where `outline` needs `fill=none stroke=currentColor`, heroicons' `mini`/`micro`
  need `viewBox` 20/16 not 24. The wrapper is the one place that genericity lives;
  each variant module bakes its own `view_box`/`defaults` into the call.
- The `Library` + `Variant` contract (the set/variant identity the placeholder
  and transformer share); the `placeholder` authoring function; and a
  `dev_resolver` hook (an injected `fn(name, attrs) -> Element`, default = fallback
  box). No by-name loader and no concrete-set import here — in Storybook the
  resolver is wired to the `apps/storybook` demo catalog, the only place allowed to
  import concrete sets.

The matching `.cn-icon-size-*` **CSS recipe still ships as a `gg_ui` fragment**
(`styles/icons.css`) — CSS is a consumer-entry concern, exactly how `button`'s
Gleam (in `gg_ui`) and its CSS recipe (a fragment) are already split. Set
packages stay Tailwind-free and immune to kit churn.

> **Alternative (rejected):** put the interface *inside* `gg_ui` and have sets
> depend on `gg_ui` directly. Same compile result, but it pulls the whole styled
> kit into every set. `gg_icon` being its **own** package — now co-located in the
> monorepo, so the "extra repo" cost that worried us is gone — keeps sets lean for
> free.

### The sizing interface — default + typed scale + escape hatch

Generated icon functions stay **trivial** — `fn(attrs) -> Element(msg)`, no size
param — so the generator is dumb and a set stays as simple as `lucide_lustre`.
Sizing rides in through `attrs`, giving all three behaviours:

```gleam
lucide.chevron_down([])                              // DEFAULT — CSS default size applies
lucide.chevron_down([icon.size(icon.Lg)])            // TYPED scale → "cn-icon-size-lg"
lucide.chevron_down([attribute.class("size-[18px]")])// ESCAPE HATCH — raw Tailwind, wins by source order
```

Interop rule (the one subtlety): the typed-scale and escape-hatch classes must
contain the `size-` token (`cn-icon-size-lg`, `size-6`, `size-[18px]`) so that,
when the icon sits inside a `gg_ui` container that injects
`[&_svg:not([class*='size-'])]:size-4`, the explicit size suppresses the
container default — identical to how shadcn and our button recipes already work.
For a genuinely non-square escape hatch (`w-[18px] h-[24px]`) the caller owns the
source-order outcome; document `size-*` (incl. arbitrary `size-[Npx]`) as the
recommended hatch.

## The generator — a shared pure-Gleam engine + a thin per-set adapter

The generation pipeline is **identical across sets** — only the *source*,
per-variant *defaults*, and any SVG *cleaning* differ. So the engine is shared,
in its own **dev-only package `gg_icon_gen`**, and each set provides a small
`Config`. It is **not** in `gg_icon`: that's the runtime interface every consumer
(and `gg_ui`) depends on, and the engine's build-only deps (`simplifile`,
`argv`, …) must never reach a shipped app. Sets depend on `gg_icon_gen` as a
**`dev_dependency`** only — kept out of the published library by living in a
nested `gen/` project (its own `gleam.toml`) that writes into `../src`, run with
`cd gen && gleam run`.

```
gg_icon_gen   shared engine (pure-Gleam SVG→Gleam + shard + emit + manifest;
  ▲  ▲  ▲     simplifile/argv for I/O). dev_dependency of each set's gen/ project.
lucide tabler …  each gen/ hands the engine a Config: per-variant source dir +
                 view_box + defaults + default flag + a `clean` hook.
```

Invoked with `gleam run` (no TypeScript — toolchain stays target-agnostic, rule
3). Deliberate choices vs `lucide_lustre`:

1. **Commit the generated `.gleam` and pin the upstream version** — vendor/pin an
   upstream snapshot, generate, commit. Reproducible, offline, version-locked. The
   cost lives in the repo, not user bundles (per-function tree-shaking).
2. **Emit against the shared `gg_icon.svg` wrapper**, so every set exposes the
   same call shape.
3. **Variant-aware.** The `Config` lists each variant with its source dir,
   `view_box`, `defaults`, and a `default: True` flag. `build` iterates **every
   variant**, emitting one module per `(variant, shard)`.
4. **`create_or_update` semantics**, three entry points (`[variant/]name`, no
   qualifier = default variant): `build` (all variants × icons), `add filled/star`
   (one icon), `update [filled/star]` (refresh changed geometry).

**SVG → Gleam is hand-rolled in the engine, not `html_lustre_converter`.**
Verified empirically: that package is **JS-only and needs a browser `DOMParser`**
(no Erlang impl; crashes under Node), so it can't run in a `gleam run` CLI. Icon
SVGs are a small, regular subset, so the engine parses the inner elements itself
and emits the matching lustre `svg.*` calls — pure Gleam, dual-target, fully
testable, and it controls the output exactly (the leaf elements `path`/`circle`/
`rect`/`line`/`ellipse`/`polygon`/`polyline` are `svg.<tag>(attrs)`; `g`/`defs`
are `svg.<tag>(attrs, children)`).

Pipeline per `(variant, icon)`: read upstream SVG → strip the wrapping `<svg>` →
parse inner elements → `clean` (per-set hook) → emit children as lustre `svg.*`
calls spliced into the variant's `gg_icon.svg(view_box:, defaults:, attrs:,
children:)` template → write/replace `pub fn <snake_name>` in the **shard module
for its first letter** (`<variant>/<letter>.gleam`; non-`a–z` → the `0` bucket,
and a digit-leading name gets an `n` prefix to stay a valid Gleam identifier).
`build` rewrites whole shard files atomically; `add`/`update` rewrite just the
one affected shard. Naming: **snake_case function names** (`chevron_down`), kebab
upstream name in the doc-comment.

**Each set ships a generated manifest** — `icons.json` (named to *not* collide
with Gleam's own `manifest.toml` dependency lockfile) — that the
CLI/transformer/registry consume: `{ variants: [...], default: "outline",
icons: { outline: { chevron_down: "c", star: "s", … }, filled: { … } } }` — i.e.
per variant, every icon name mapped to its **shard**. That's the allow-list *and*
the `name → shard` resolution the transformer needs; it fails loudly on a typo'd
name, a wrong variant, or a name absent from the requested variant.

> All generation deps (`gg_icon_gen`, `simplifile`, `argv`) are **dev-only**,
> confined to each set's nested `gen/` project — never a runtime dep of `gg_icon`,
> `gg_ui`, or the generated modules.

### The two launch sets: lucide + tabler

The first two sets are **lucide** (the shadcn default, one variant) and
**tabler** (two variants: `outline` + `filled`), chosen over
phosphor/hugeicons/remixicon because tabler is the **largest fully-open (MIT)**
set, has **no free/pro split** (unlike hugeicons), and is structurally a twin of
lucide — 24×24, 2px stroke, `currentColor`, round caps. Tabler's `filled`
variant is also why **the very first non-lucide set already exercises the variant
machinery** — variants are not a future concern we can stub out.

## Variants — first-class

A variant is a rendering style with its own geometry, `viewBox`, and SVG defaults
(stroke vs fill). The whole system keys on `(set, variant)`.

**Model.** Each set declares its variants and **one default variant**. lucide:
`[lucide]`, default `lucide`. tabler: `[outline, filled]`, default `outline`.
heroicons (later): `[outline, solid, mini, micro]`, default `outline`.

**Why per-usage, not per-project.** The set is the project-wide choice
(`iconLibrary`), but the variant is **per icon usage** — a real UI uses
tabler/heroicons `outline` for most things and `filled`/`solid` for active or
emphasised states *on the same screen*. So the variant can't be a global setting;
the registry author picks it at each call site.

**Encoding.** The placeholder value is `"[<variant>/]<name>"`. No qualifier ⇒ the
set's default variant:

```gleam
icon.placeholder(
  lucide:  "chevron_down",          // 1-variant set → never qualified
  tabler:  "chevron_down",          // → default variant (outline)
  attrs:   [icon.size(icon.Sm)],
)

icon.placeholder(
  lucide:  "star",
  tabler:  "filled/star",           // explicit variant
  attrs:   [icon.size(icon.Sm)],
)
```

**Module layout — `<variant>/<shard>`, sharded by first letter** (see
[Module sharding](#one-module-per-variant--sharded-by-first-letter) for the
size/compile rationale). A variant is a directory; each shard module holds the
icons whose name starts with that letter (`0` bucket = digit/other):

```
gg_icons_lucide/src/gg_icons_lucide/lucide/c.gleam   # single-variant set: variant dir = set name
gg_icons_tabler/src/gg_icons_tabler/outline/c.gleam  # default variant, "c" shard
gg_icons_tabler/src/gg_icons_tabler/outline/s.gleam
gg_icons_tabler/src/gg_icons_tabler/filled/s.gleam   # named variant
```

Each module bakes its variant's `view_box` + `defaults` into the shared
`icon.svg` wrapper:

```gleam
// gg_icons_tabler/.../filled/s.gleam   (all filled icons starting with "s")
const filled_defaults = [#("fill", "currentColor")]   // no stroke — a solid glyph

pub fn star(attrs: List(Attribute(msg))) -> Element(msg) {
  icon.svg(view_box: "0 0 24 24", defaults: filled_defaults, attrs: attrs,
           children: [svg.path([attribute.attribute("d", "…")])])
}
```

Everything stays `currentColor`, so `color`/`text-*` drives the icon and the
**sizing interface is fully orthogonal** — `icon.size(...)` and the `size-*`
escape hatch work identically across variants. (Duotone weights like phosphor's,
if ever added, need a *second* colour — a per-variant `defaults` + a CSS var for
the secondary layer; out of scope until a duotone set is on the table.)

**Why module-per-`(variant, shard)`** (vs. a runtime `variant` argument): each is
an independent ESM module, so the bundler tree-shakes per `(variant, icon)` —
using only `outline/c.chevron_down` never pulls any `filled` geometry; the
transformer target is unambiguous; and generated functions stay trivial
(`fn(attrs)`), so the
generator never branches on variant inside a function body.

## Bundling & code-splitting (Vite)

Gleam's JS target emits **one `.mjs` per module**, every `pub fn` is a **named
ESM export**, and generated icon modules have **no module-scope side effects**
(just imports + `export function`/`export const`/`class` declarations — verified
against the existing compiled `gg_ui` output). That is the ideal shape for the
production bundler.

### One module per variant — sharded by first letter

Each variant is split into **shard modules by the icon's first letter**
(`outline/a.gleam`, `outline/b.gleam`, … `outline/0.gleam` for digit/other) —
**not** one giant module, and **not** a file per icon. Three layouts, weighed
across the build stages:

| layout | Gleam compile | prod bundle | module size | dev/Storybook |
| --- | --- | --- | --- | --- |
| monolith (1/variant) | whole pkg; one **LSP-hostile** unit | tree-shakes | **~1 MB .mjs** | huge module, coarse HMR |
| **shard a–z (~27/variant)** | whole pkg; small healthy units | tree-shakes | **~tens of KB** | small modules, fine HMR |
| file-per-icon (thousands) | **thousands of modules** | tree-shakes | tiny | tiny |

Two facts pin the choice:

- **Gleam compiles the *whole dependency package*** — verified: `lustre` ships 40
  modules and all 40 compile even though `gg_ui` imports 4. So all layouts pay to
  compile every icon; the axis that matters is **module *count* and *size***.
  Thousands of modules (file-per-icon) is bad; ~27/variant (≈270 across 5 sets ×
  2 variants) is trivially fine — lustre+stdlib alone already pull ~60.
- **JS bundle size scales with icons *used*** — Rollup does per-export DCE on the
  pure, side-effect-free named exports, so the production bundle contains only the
  icons actually called **regardless of layout** (neutral).

Sharding wins every non-tied axis: no ~1 MB blob, LSP-friendly modules, fine HMR,
manageable module count. **Costs, recorded honestly:**

- The **shard letter leaks into generated imports** — a file using `chevron_down`
  + `square` from tabler outline gets `import …/outline/c` and `import …/outline/s`
  and calls `c.chevron_down` / `s.square`. A single re-export facade would import
  every shard and kill tree-shaking, so the shard is unavoidable in the import.
  The manifest maps `name → shard` so authors never type it; it appears only in
  generated/installed code, and shard letters are stable (chevron is always `c`).
- Buckets are **uneven** (popular letters like `a`/`c`/`s` are big). Fine; if one
  ever gets heavy enough to matter, sub-shard it (`c1`, `c2`) — a contained,
  manifest-driven tweak.

- **Tree-shaking: yes.** Vite's production build is Rollup. Each shard's `.mjs` of
  pure named exports → Rollup drops every export you don't reference, and any
  shard module you never import never enters the graph. **The bundle contains only
  the icons actually called.**
- **Code-splitting (separate lazy chunks): no, and you don't want it for icons.**
  Each icon is a few hundred bytes of path data rendered synchronously inside a
  view; a network round-trip per icon would be strictly worse. Statically-called
  icons fold into whichever chunk references them; if that chunk is route-split,
  they ride along for free.
- **No load-everything switch by avoiding the `*_by_name` loader.** A generated
  `case name { … }` over every icon would reference the whole set and never
  tree-shake. We don't ship one: production uses direct static calls (transformer
  output → Rollup prunes), and Storybook uses the **bounded ~20-icon curated demo
  catalog** (see [the dev/docs runtime](#the-dev--docs-runtime-storybook-switching)),
  so even the live switcher pulls only those ~20 across sets/variants — not the
  set. Both paths are statically analysable; neither defeats DCE.
- **Dev vs prod.** Vite *dev* uses esbuild and does not tree-shake — a story may
  load more than it strictly uses in dev. Only the production Rollup build prunes;
  judge bundle size from the production build. The curated catalog keeps even the
  un-pruned dev surface small.

## The placeholder — our equivalent

Gleam has no JSX, so the placeholder is a plain function (in `gg_icon`) with one
labelled argument per **set**:

```gleam
// gg_icon/src/gg_icon/placeholder.gleam
pub fn placeholder(
  lucide lucide: String,
  tabler tabler: String,
  attrs attrs: List(Attribute(msg)),
) -> Element(msg) {
  // Authoring construct. In PRODUCTION the transformer replaces this whole call
  // with a direct `s.x(attrs)` for the picked set — see below. In DEV it resolves
  // through a registered resolver (Storybook injects the demo catalog); with no
  // resolver (SSR/BEAM/non-storybook) it renders a neutral fallback box.
  case dev_resolver() {
    Ok(resolve) -> resolve(lucide, attrs)   // resolver reads the active set/variant
    Error(_) -> fallback_box(attrs)
  }
}
```

> **`gg_icon` stays set-agnostic.** The `dev_resolver` is an injected
> `fn(name, attrs) -> Element` (an FFI dev-global the Storybook app sets once), so
> `gg_icon` never imports a `gg_icons_*` package — the concrete-set dependency
> lives only in `apps/storybook`, where the resolver *is* the demo catalog's
> by-name lookup. Production never reaches this body (the transformer deletes the
> call), so the resolver is a pure dev-preview hook.

### Embedded icons are placeholders too (e.g. dialog-close `x`)

When a gg_ui component **embeds** an icon — the `x` in a dialog close, a select's
chevron, a checkbox's check — that icon is written as `icon.placeholder(...)` in
the component's **registry source**, exactly like a caller-supplied one. So:

- **Production:** `gg-ui add dialog` transforms the embedded `x` to the user's
  picked set/variant (`s.x(...)`) — the close button follows their icon choice,
  no special case, fully tree-shaken.
- **Storybook:** the embedded placeholder hits the `dev_resolver` → demo catalog,
  so the dialog's `x` **previews and switches live** with the toolbar (every
  embedded glyph — `x`, chevrons, `check` — is in the curated ~20). No per-component
  threading needed: the resolver reads the active global set/variant, and a
  toolbar change re-renders the story.

The only residual limit: an embedded name *outside* the curated catalog would show
the fallback box in dev (still correct in production). Keep embedded glyphs within
the curated set, or extend the catalog — both cheap.

Registry source uses it identically across sets; the value carries the variant
qualifier (see [Variants](#variants--first-class)):

```gleam
icon.placeholder(
  lucide: "star",
  tabler: "filled/star",
  attrs: [icon.size(icon.Sm)],
)
```

After `gg-ui add`, the transformer resolves the configured set's value to its
variant **shard** module (the manifest maps `name → shard`):

```gleam
// iconLibrary: "tabler"  →  "filled/star" → filled variant, "s" shard
import gg_icons_tabler/filled/s
// …
s.star([icon.size(icon.Sm)])

// iconLibrary: "lucide"  →  "star" (no qualifier) → default variant, "s" shard
import gg_icons_lucide/lucide/s
// …
s.star([icon.size(icon.Sm)])
```

No branching, no runtime cost, no placeholder. (Two icons from the same variant
but different shards produce two imports — `…/c` and `…/s`; the shard letter is
generated, never authored.)

## The transformer

The Gleam analogue of `transformIcons.ts`. Lives **CLI-side** (TypeScript is
fine here — it never ships in library code). Inputs: a `.gleam` file's text +
`components.json.iconLibrary`. Output: the same file with placeholder calls
rewritten. The rewrite is **syntactic**, not semantic — `icon.placeholder(...)`
is unambiguous, so no full Gleam parser is needed:

1. Match parens-balanced `icon.placeholder(...)` calls.
2. Pull the labelled argument for the configured set + the `attrs:` argument.
3. Split the value into `[variant/]name`; resolve `variant` (explicit, else the
   set manifest's `default`) and look up the icon's `shard` in the manifest.
4. Replace the call with `<shard>.<icon>(<attrs>)`.
5. Add `import gg_icons_<set>/<variant>/<shard>` if missing.
6. Remove the `gg_icon/placeholder` import if now unused.

We pin a formatter-friendly call shape (one labelled arg per line) in registry
source so the matcher stays simple. Validate `(variant, icon)` against the set's
generated manifest and fail loudly on a bad name (`tabler/filled has no icon
"chevron_dwon" — did you mean "chevron_down"?`) **or a bad variant** (`tabler has
no variant "fild" — variants: outline, filled`).

## The dev / docs runtime (Storybook switching)

We want live set/variant switching in Storybook — flip a toolbar dropdown, watch
button-with-icon and tooltip re-render in the chosen set. The naive way (a
generated `*_by_name` loader over **every** icon) is a tree-shaking killer and
forces the whole set to load. **We don't do that.** Instead Storybook is treated
as a *real consumer*: it uses a small **curated demo catalog** of ~20 typical
icons that exist across every shipped `(set, variant)`. Bounded to ~20 names, the
catalog references at most a few hundred functions total — fine to load fully, no
load-everything problem.

**1. The demo catalog lives in `apps/storybook`** (dev-only; it path-depends on
the icon-set packages — it must never live in `gg_icon`, which would couple the
interface package to concrete sets). It branches over a *typed* enum, so a missing
case is a compile error, not a runtime miss:

```gleam
// apps/storybook/src/.../demo_icons.gleam
import gg_icons_tabler/filled/s as tabler_filled_s
import gg_icons_tabler/outline/s as tabler_outline_s
import gg_icons_lucide/lucide/s as lucide_s
// … only the shards the ~20 demo icons fall into

pub type DemoIcon { ChevronDown Check Close Search Settings User Star Heart /* ~20 */ }

pub fn render(set: IconSet, variant: IconVariant, which: DemoIcon, attrs) -> Element(msg) {
  case set, variant, which {
    Tabler, Filled, Star  -> tabler_filled_s.star(attrs)
    Tabler, Outline, Star -> tabler_outline_s.star(attrs)
    Lucide, _, Star       -> lucide_s.star(attrs)
    // …
  }
}
```

The catalog is **validated against each set's manifest** at build time: every
demo name must exist in every shipped `(set, variant)`, or be explicitly marked
outline-only (see the fill-coverage note below). No hand-asserted coverage.

**2. Global toolbar selectors — `Icon set` + `Icon variant`** — added to
`.storybook/preview.ts` `globalTypes`, next to the existing Shape / Base color /
Theme / Mode dropdowns. A decorator publishes the active values to a JS dev-global
and registers the catalog's by-name lookup as the `gg_icon` **`dev_resolver`** (so
`icon.placeholder` in any rendered component resolves through the same catalog).

**3a. Embedded icons resolve automatically.** A gg_ui component that embeds an
icon (dialog-close `x`, select chevron) keeps its `icon.placeholder(...)` in dev;
its dev body calls the registered resolver → demo catalog → the active set/variant
([see above](#embedded-icons-are-placeholders-too-eg-dialog-close-x)). No
threading: flipping the toolbar re-renders the story and the embedded icon
switches.

**3b. Decorative story icons thread the globals.** When a *story itself* adds an
icon for show (a button's leading glyph), it reads `globals` and forwards them
into its `mount_*`, calling the typed `demo_icons.render(set, variant, which, …)`:

```ts
render: (args, { globals }) =>
  mountLustre((sel) =>
    mount_button(sel, args.variant, globals.iconSet, globals.iconVariant)),
```

Either way a toolbar flip re-runs `render` → re-mounts with the new icons →
**button and tooltip icons switch live**. (An icon-set flip remounts the story,
resetting transient state like an open popover — acceptable for a dev tool, and
only for stories that show icons.)

**4. An icon-gallery story** renders all ~20 demo icons in a grid, driven by the
same two controls — the visual proof every `(set, variant)` renders.

### The ~20 demo icons + the fill-coverage caveat

Typical UI set: `chevron-down`, `chevron-right`, `check`, `x`, `search`,
`settings`, `user`, `home`, `calendar`, `plus`, `trash`, `pencil`, `info`,
`alert-triangle`, `star`, `heart`, `bell`, `menu`, `arrow-right`, `external-link`.

A `filled`/`solid` variant has **no meaningful form for stroke-only glyphs**
(chevrons, arrows — tabler `filled` is ~1,400 vs ~5,900 `outline`). So:

- **Set-switching** uses all ~20 (every set has them in its default variant).
- **Variant-switching** uses the *fillable subset* (`star`, `heart`, `bell`,
  `user`, `home`, `settings`, `info`, `calendar`, …); a stroke-only glyph under a
  fill variant **falls back to outline**, flagged in the catalog so it's a
  deliberate fallback the manifest check enforces, never a surprise.

> A *future* full icon browser on the docs site (search all ~5,900) is a separate,
> load-everything concern — solve it there with a lazy/​paginated TS loader
> (shadcn's `createIconLoader` style), not the Lustre render path. Storybook stays
> on the bounded curated catalog.

## How icon sets appear in the `gg_ui` registry

One `registry:item` per set, describing its Hex package:

```jsonc
{
  "name": "icon-tabler",
  "type": "registry:item",
  "title": "Tabler Icons",
  "description": "Over 5,900 free MIT-licensed icons.",
  "dependencies": ["gg_icons_tabler"],
  "variants": ["outline", "filled"],   // mirrors the set manifest
  "defaultVariant": "outline",
  "files": []
}
```

`gg-ui init` (pick a set) → CLI sets `iconLibrary: "tabler"` in
`components.json`, adds `gg_icons_tabler` to `gleam.toml`, and ensures the
`.cn-icon-*` CSS fragment is in the entry. From then on every `gg-ui add`
transforms placeholders to that set's variant-resolved calls. The `variants` /
`defaultVariant` here are a convenience mirror of the package's generated
manifest, which remains the source of truth the transformer validates against.

## Failure modes & guardrails

- **Unknown icon name / unknown variant** — transformer fails loudly against the
  per-`(variant)` manifest (baked at generation time), with a did-you-mean for
  both the icon name and the variant list.
- **Icon exists in the default variant but not the requested one** (e.g. a glyph
  drawn only as `outline`, no `filled`) — fail loudly; the author either picks an
  available variant or omits the qualifier to fall back to the default. The
  manifest makes this checkable at transform time, not a runtime surprise.
- **A set missing an icon another set has** — each placeholder declares one
  `[variant/]name` per set; if the chosen set lacks it, the transformer warns and
  falls back to a generic square (or the author's designated fallback — TBD when
  we hit a real conflict; most sets cover the shadcn-required set).
- **An icon we haven't generated** — escape hatch: depend on the set package and
  call its variant module directly, or run its `add [variant/]<name>` generator.
  Supported and documented.

## Implementation order

1. **`gg_icon`** — `Size` + `icon.size`, the variant-generic `icon.svg` wrapper,
   `placeholder` (fallback-box dev body). Add the `.cn-icon-size-*` CSS fragment
   to `gg_ui/styles` and wire it into the Storybook entry. ✅ *built (slice)*
2. **`gg_icon_gen`** — the shared engine: hand-rolled SVG→Gleam (parse inner →
   emit lustre `svg.*` → splice into `gg_icon.svg`), `name → shard` bucketing,
   module + `icons.json` rendering (pure core), plus `simplifile`/`argv` I/O for
   `build`/`add`/`update`.
3. **`gg_icons_lucide`** (1 variant) + **`gg_icons_tabler`** (`outline` + `filled`)
   — each a `gen/` project handing `gg_icon_gen` its `Config` (sources, per-variant
   `view_box`/`defaults`, default flag, `clean` hook); run it to generate the
   committed shards + `icons.json` from pinned upstream. Tabler **proves variants
   end-to-end** — it ships filled. ✅ *hand-baked slice built; generator next*
4. **Storybook demo catalog + toolbar** — the curated ~20-icon `demo_icons.gleam`
   in `apps/storybook` (manifest-validated), the `Icon set`/`Icon variant`
   `globalTypes`, an icon-gallery story, and one component story (button/tooltip)
   threading the globals to switch its icon live.
5. **Transformer** — pure TS function with variant + `name → shard` resolution
   against the manifest, testable today against registry source; wired into the
   CLI later.

## Open questions

- **`gg_icon` interface package vs. interface-in-`gg_ui`.** Recommending the slim
  `gg_icon` package (lean set deps, no kit coupling); the in-`gg_ui` variant is
  the simpler-package-count fallback.
- **Non-square escape hatch.** `size-[Npx]` is the clean, token-carrying hatch;
  `w-* h-*` works but the caller owns source-order vs. any container default.
  Document the recommended path; revisit if real non-square demand appears.
- **Shard scheme.** Resolved for now: **first letter** (`<variant>/a..z` + `0`
  for digit/other), derivable, stable, human-meaningful. Alternative considered:
  fixed-size buckets (even sizes, but bucket isn't derivable from the name and the
  letter is more legible in imports). Sub-shard a too-large letter (`c1`, `c2`)
  only if one bucket gets heavy. The single-variant case still nests under the
  set-named variant dir (`gg_icons_lucide/lucide/<shard>`).
- **Duotone / multi-colour variants** (phosphor `duotone`): need a second colour
  beyond `currentColor` — a per-variant `defaults` + a CSS var for the secondary
  layer. Designed-for but unbuilt until a duotone set is on the table.
- **Stroke-width / weight as a value vs. a variant.** Phosphor models weight as a
  variant (six modules); a finer `stroke-width` tweak is better left to CSS
  (`stroke-width` via a CSS var on the parent) — the generated `..attrs` still
  lets a caller pass one explicitly.
</content>
</invoke>

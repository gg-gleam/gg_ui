# Icons

How a consuming Gleam project gets icons, how registry source stays
icon-library-agnostic, and how the (future) CLI rewrites placeholders at
`gg-ui add` time. **Same shape as shadcn** — placeholder in source + transformer
at install time — with one critical difference: we emit **inline SVG**, not
imports from `lucide-react`-style npm packages, so it works on both Lustre
targets.

## The constraint that decides everything

Lustre compiles to JS *and* to Erlang. A "server component" that uses Lustre
on the BEAM cannot import `lucide-react`. Even a JS-only project consuming
icons via FFI is awkward — you'd be loading a 30-icon React-flavoured tree-
shaken bundle for no reason.

**So we pre-generate `gg_ui/icons/<library>.gleam` modules** that emit Lustre
SVG elements directly, with the path data baked in as Gleam string constants.
One function per icon. Zero npm runtime dependency.

```gleam
// generated: src/gg_ui/icons/lucide.gleam
pub fn chevron_down(attrs: List(Attribute(msg))) -> Element(msg) {
  svg.svg(
    [
      attribute.attribute("viewBox", "0 0 24 24"),
      attribute.attribute("fill", "none"),
      attribute.attribute("stroke", "currentColor"),
      attribute.attribute("stroke-width", "2"),
      ..attrs
    ],
    [svg.path([attribute.attribute("d", "m6 9 6 6 6-6")])],
  )
}
```

That's it. Works on JS. Works on BEAM. Tree-shakes per-icon-function (Gleam's
unused-export elimination handles it). No bundler config.

## How shadcn does it (for reference)

Three layers:

1. **`IconPlaceholder`** — a JSX component in registry source that takes one
   prop per supported library: `<IconPlaceholder lucide="ChevronDownIcon"
   tabler="IconChevronDown" phosphor="CaretDownIcon" />`. Renders a generic
   SVG box in the docs site.
2. **`transformIcons`** — a TypeScript AST pass (`ts-morph`) that runs when
   `shadcn add ...` writes a component. Reads `components.json.iconLibrary`,
   finds every `<IconPlaceholder>`, replaces with the matching library's
   import + JSX (`<ChevronDownIcon />`), strips the placeholder import.
3. **`createIconLoader`** — a runtime React component the **docs site**
   uses to render any icon by name across libraries (powers the "preview in
   lucide / tabler / phosphor" toggle on ui.shadcn.com). **Not used in
   user code** — only in the docs site's preview.

We adopt (1) and (2). We replace (3) — the docs-site preview — with the same
trick (a Lustre component that branches on `iconLibrary` to pick a generated
`gg_ui/icons/<lib>.gleam` function).

## Our equivalent — the placeholder

Gleam doesn't have JSX, so the placeholder is a plain function with one
labelled argument per library:

```gleam
// src/gg_ui/icons/placeholder.gleam
import lustre/element.{type Element}
import lustre/attribute.{type Attribute}

pub fn placeholder(
  lucide lucide: String,
  tabler tabler: String,
  phosphor phosphor: String,
  hugeicons hugeicons: String,
  remixicon remixicon: String,
  attrs attrs: List(Attribute(msg)),
) -> Element(msg) {
  // In the dev / docs runtime, branch on the configured library
  // (read from a Lustre context or a build-time constant).
  // In *production* (post-CLI-transform), this entire call is
  // replaced by a direct call into gg_ui/icons/<lib>.<name>(attrs).
  fallback_square(attrs)
}
```

A registry component using it looks identical across libraries:

```gleam
icons.placeholder(
  lucide: "chevron_down",
  tabler: "icon_chevron_down",
  phosphor: "caret_down",
  hugeicons: "arrow_down_01_icon",
  remixicon: "arrow_down_s_line",
  attrs: [attribute.class("size-4")],
)
```

That's what lives in registry source. After `gg-ui add` with `iconLibrary:
"lucide"` and the icon-rewrite transformer, the file on disk contains:

```gleam
import gg_ui/icons/lucide

// ...
lucide.chevron_down([attribute.class("size-4")])
```

No conditional branching, no runtime cost.

## The transformer

The Gleam analogue of `transformIcons.ts`. Inputs: a `.gleam` file's text +
`components.json.iconLibrary`. Outputs: same file with placeholder calls
rewritten.

The rewrite is *syntactic*, not semantic — we don't need a full Gleam parser
because `icons.placeholder(...)` is unambiguous:

```
icons.placeholder(
  lucide: "<name>",
  tabler: "<name>",
  ...
  attrs: <expr>,
)
```

Algorithm:

1. Match `icons.placeholder(...)` calls with a regex / hand-written tokenizer
   (parens-balanced).
2. Pull out the labelled argument matching the configured library.
3. Pull out the `attrs:` argument.
4. Replace the call with `<library>.<icon>(<attrs>)`.
5. Add `import gg_ui/icons/<library>` to the top of the file if missing.
6. Remove `import gg_ui/icons/placeholder` if it's no longer used.

This is small enough to implement without `tree-sitter-gleam`. We pin to a
formatter-friendly call shape (one labelled argument per line) in registry
source so the regex stays simple. Edge cases (multi-line strings, nested
parens in `attrs`) are rare enough that we can iterate.

## Generating the icon modules

The `gg_ui/icons/<library>.gleam` files are **generated**, not hand-written.
Source of truth is each library's upstream icon data:

| Library    | Upstream source                                      | Format                  |
| ---------- | ---------------------------------------------------- | ----------------------- |
| lucide     | `lucide/icons/*.json` (one file per icon)            | JSON (name + svg paths) |
| phosphor   | `@phosphor-icons/core` ICON data                     | SVG strings             |
| tabler     | `@tabler/icons/icons/*.svg`                          | SVG files               |
| hugeicons  | `@hugeicons/core-free-icons` exports                 | Path-array JSON         |
| remixicon  | `remixicon/icons/**/*.svg`                           | SVG files               |

A build script (`scripts/build-icons.ts` — TypeScript, runs once per
release):

1. Reads upstream icon data for the configured library.
2. Strips wrapping `<svg ...>` → extracts inner `<path>` / `<g>` / `<rect>` etc.
3. Emits one Gleam function per icon, with attrs pass-through.

```ts
// pseudocode
for (const icon of lucideIcons) {
  const inner = parseSvgInner(icon.svg)
  emit(`
pub fn ${toSnakeCase(icon.name)}(attrs: List(Attribute(msg))) -> Element(msg) {
  svg.svg(
    [attribute.attribute("viewBox", "0 0 24 24"),
     attribute.attribute("fill", "none"),
     attribute.attribute("stroke", "currentColor"),
     attribute.attribute("stroke-width", "2"),
     attribute.attribute("stroke-linecap", "round"),
     attribute.attribute("stroke-linejoin", "round"),
     ..attrs],
    [${gleamSvgChildren(inner)}],
  )
}
`)
}
```

We commit the generated files. They're large (1000+ icons × a few lines each)
but tree-shake per-function so the production bundle only contains what's
actually used. The cost lives in the repo, not in user bundles.

Naming convention: **snake_case Gleam function names**. The placeholder's
labelled-argument values are the snake_case names (`lucide: "chevron_down"`,
not `"ChevronDownIcon"`). We document the mapping in each generated file's
top doc-comment.

## One generated module per library

Don't try to be clever and unify them. shadcn keeps them separate
(`__lucide__.ts`, `__phosphor__.ts`, etc.) because the SVG attributes differ
per library (lucide has `stroke-linecap`, phosphor has `weight`, hugeicons
has its own props). Each module bakes the right defaults into its `svg.svg`
call.

The naming convention `gg_ui/icons/<library>.gleam` is fixed. The
transformer assumes it.

## The dev / docs runtime

For Storybook stories and the docs site we *do* want runtime library
switching — pick lucide from the toolbar, watch every story re-render with
lucide icons. The Lustre version of shadcn's `createIconLoader` is:

```gleam
// src/gg_ui/icons/loader.gleam
pub fn render(library: Library, name: String, attrs: List(Attribute(msg))) -> Element(msg) {
  case library {
    Lucide -> lucide_by_name(name, attrs)
    Tabler -> tabler_by_name(name, attrs)
    Phosphor -> phosphor_by_name(name, attrs)
    ...
  }
}
```

`lucide_by_name` is a giant `case name { "chevron_down" -> lucide.chevron_down(attrs)
... }`. Generated. Not for user code — only for the docs/Storybook root.

## How icon libraries appear in the registry

A `registry:item` per library, describing its package + the placeholder usage:

```jsonc
{
  "name": "icon-lucide",
  "type": "registry:item",
  "title": "Lucide",
  "description": "Beautiful & consistent icons.",
  "dependencies": ["gg_ui_icons_lucide"],
  "files": []
}
```

When a user runs `gg-ui init` and picks lucide, the CLI:

1. Sets `iconLibrary: "lucide"` in `components.json`.
2. Adds the `gg_ui_icons_lucide` Hex package to `gleam.toml`.
   (Or, if we ship the icon modules as part of `gg_ui` itself, no extra
   dep — TBD, see open questions.)

The Hex packages are slim Gleam-only packages containing the generated
modules and nothing else.

## Failure modes & guardrails

- **Placeholder with an unknown icon name** — the transformer fails loudly
  ("`lucide` has no icon called `chevron_dwon` — did you mean `chevron_down`?").
  We bake an allow-list per library at generation time.
- **A library missing a corresponding icon** — every placeholder declares one
  name per library. If the user picks a library where the icon doesn't
  exist, the transformer falls back to the registry author's choice (TBD)
  or warns and uses a generic square. We'll define this when we have a
  real conflict; most icon libraries have visual equivalents for the
  shadcn-required set.
- **A user wants an icon we haven't generated** — escape hatch: import a
  per-library Hex package and call its function directly. Bypasses the
  placeholder system; supported and documented.

## Implementation order

1. Write `gg_ui/icons/placeholder.gleam` and the dev-runtime fallback (just
   renders a square).
2. Pick lucide first. Write `scripts/build-icons.ts`. Generate
   `gg_ui/icons/lucide.gleam`. Commit it.
3. Migrate one existing component (e.g. `popover.close`) to use the
   placeholder for its chevron-ish icons. Confirm Storybook renders.
4. Generate phosphor + tabler. Three libraries is enough to prove the
   pattern (and matches shadcn's "primary" tier).
5. Write the transformer as a pure-function TypeScript module. Test it
   against the registry source files directly. It runs in the (future)
   CLI but the function itself is testable today.

## Open questions

- **Bundle the icon modules with `gg_ui` or split?** Splitting (separate
  Hex packages per library) means a project only installs the icons it
  uses. Bundling makes `gleam add gg_ui` self-contained. Tentative: **split**
  — the generated `lucide.gleam` is hundreds of KB and we don't want
  uninterested users paying for it. The CLI handles the `gleam add
  gg_ui_icons_lucide` step transparently.
- **Stroke-width and other per-call overrides.** lucide takes
  `strokeWidth` as a prop. Our generated functions accept any attrs, so a
  caller can pass `attribute.attribute("stroke-width", "1.5")` — but
  styling-by-prop is awkward. Better: callers use CSS (`.size-4` resolves
  size; `stroke-width` set via a CSS variable on the parent). Document
  the pattern.
- **24×24 vs other sizes.** Most icon libraries are 24×24. Phosphor has
  variable weights. Tabler is 24×24. We bake `viewBox="0 0 24 24"` into
  the generators per-library and document any deviations.

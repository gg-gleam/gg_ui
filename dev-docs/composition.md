# Composition

How `gg_ui` adapts Base UI's composition model
([base-ui.com/react/handbook/composition](https://base-ui.com/react/handbook/composition))
to Lustre. Read this once before adding a new component so the layering stays
consistent.

## What Base UI does

Base UI components are split in two:

1. **`useX`** (e.g. `useButton`) — a hook returning a *bag of headless props*:
   ARIA, keyboard handlers, `type`/`disabled`/`tabindex`, anything semantic.
2. **`useRender`** — merges those props onto either a default element
   (`<button>`) or a `render` element the caller provides (`render={<a />}`,
   `render={<MyLink />}`). Merging is special-cased: event handlers stack,
   `className` strings concatenate, `style` objects merge, everything else is
   overridden right-to-left.

The result: `<Button render={<a href="/x" />} />` keeps all the behavior and
ARIA the headless layer produces, but renders an `<a>` instead.

## What Lustre gives us

Lustre has no `render` prop, no `useRender`, no children-as-elements. A
component is just `fn(...) -> Element(msg)`, and an element is a tag + a list of
attributes + children. Two consequences:

- **No element cloning.** The caller can't hand us a `<a />` and ask us to graft
  props onto it; they have to construct the element themselves.
- **Attribute lists merge with special cases.** Concatenating two
  `List(Attribute(msg))` just appends. At render time Lustre's vdom
  ([`vattr.merge`](../build/packages/lustre/src/lustre/vdom/vattr.gleam))
  special-cases `class` (space-joined) and `style` (`;`-joined) — same idea as
  `mergeProps`. Everything else is last-wins, including event handlers (so a
  caller's `on_click` *replaces* a handler from the headless layer rather than
  stacking with it).

## The two layers

The two layers are now two **packages**:

```
packages/gg_base_ui/src/gg_base_ui/<name>/<name>.gleam   — headless: attributes only (emits no Tailwind/CSS, own Hex package, imported not ejected)
packages/gg_ui/src/gg_ui/ui/<name>.gleam                 — thin styled: cn-* class names + convenience renderers
```

### Headless layer (`gg_base_ui/...`)

The `useX` equivalent. Exposes:

- A `Config` record with the component's behavior knobs (`disabled`,
  `focusable_when_disabled`, …).
- A `config()` constructor returning the Base UI defaults.
- **`attributes(config, target) -> List(Attribute(msg))`** — the `useX` output.
  This is the composition primitive. Callers merge it onto whatever element
  they're rendering.
- An optional `<name>(config, attrs, children)` convenience that renders the
  default element (e.g. `html.button`) with `attributes` prepended.

The `target` parameter is our answer to Base UI's element-aware behavior — see
[Targets](#targets) below.

### Styled layer (`gg_ui/ui/...`, package `gg_ui`)

The shadcn-recipe layer. Imports the headless layer and `gva` and exposes:

- `Variant`, `Size`, and any other axis types.
- **`classes(variant, size, …) -> String`** — the recipe. Exported so callers
  can apply it to any element (the stand-in for `render={<a className=…>}`).
- Convenience renderers: `<name>(...)` for the default element, plus a small
  set of "render-as-X" renderers (e.g. `link(...)` for `<a>` styled as button)
  for the common non-default cases.

## How to compose: three patterns

All public styled and headless functions take **labeled arguments**, so call
sites read like Base UI prop bags. Positional calls still work; prefer labels at
the boundary between layers.

### 1. Default element — use the convenience

```gleam
styled_button.button(
  variant: styled_button.Default,
  size: styled_button.Medium,
  attrs: [event.on_click(Clicked)],
  children: [html.text("Save")],
)
```

The styled `button` calls `base_button.button`, which spreads
`base_button.attributes(config:, target: Native)` for you.

### 2. Pre-baked alternate element — use the named convenience

```gleam
styled_button.link(
  variant: styled_button.Link,
  size: styled_button.Medium,
  attrs: [attribute.href("/docs")],
  children: [html.text("Docs")],
)
```

`link` renders `<a data-slot="button">` with the recipe applied, and
deliberately does *not* merge `base_button.attributes` — see
[Anchors aren't NonNative](#anchors-arent-nonnative).

### 3. Ad-hoc render-as-something-else — build the element yourself

The Lustre stand-in for `render={<MyThing />}`:

```gleam
html.div(
  list.flatten([
    base_button.attributes(
      config: base_button.config(),
      target: base_button.NonNative,
    ),
    [
      attribute.attribute("data-slot", "button"),
      attribute.class(styled_button.classes(
        variant: styled_button.Default,
        size: styled_button.Medium,
      )),
      event.on_click(Clicked),
    ],
  ]),
  [html.text("Pseudo-button")],
)
```

The pattern: `headless.attributes(...) ++ your_attrs`. Your attrs go *after*
so they win on conflicts (last-wins for plain attrs, concat for `class` and
`style`).

## Targets

Base UI's `useButton` adapts to whether you render it as a real `<button>` or
something else: native buttons get `type="button"` and the HTML `disabled`
attribute; non-natives get `role="button"`, `tabindex`, and `aria-disabled`. We
mirror that with an explicit `Target` parameter on `attributes`:

```gleam
pub type Target {
  Native     // <button>
  NonNative  // <div>, <span>, … acting as a button
}
```

`base_button.button` always passes `Native`. Callers in pattern 3 pass
`NonNative` (and accept that they own keyboard activation — see
[Limitations](#limitations)).

### Anchors aren't NonNative

`<a href>` is a link, not a button. The browser already activates it on Enter
and the AT already announces "link". Putting `role="button"` + `tabindex` +
`aria-disabled` on it would override the link semantics and mislead screen
reader users. That's why `styled_button.link` skips `base_button.attributes`
entirely — and why `Target` is just `Native | NonNative`, not a third
`Anchor` variant.

If you want a link that *behaves* like a form button (no navigation, runs a
handler), don't use `<a>` — use `styled_button.button` with `type="button"`
already set, or build a real `<button>`.

## Extra classes from the caller

This is the easy case in Lustre — easier than I first thought, easier than
React. The vdom merges duplicate `class` attributes by space-joining:

```gleam
[ attribute.class("a b"), attribute.class("c d") ]
// rendered: class="a b c d"
```

(See `lustre/vdom/vattr.gleam:117-126`.) `style` is the same with `;`. So
callers don't need a special escape hatch for extra classes — they just pass a
second `attribute.class("…")` through `attrs` and Lustre merges it with the
recipe's class string at render time:

```gleam
styled_button.button(
  variant: styled_button.Default,
  size: styled_button.Medium,
  attrs: [
    attribute.class("ml-2 shadow-sm"),
    event.on_click(Clicked),
  ],
  children: [html.text("Save")],
)
```

That's the answer to "should we expose an `extra: String` param?" — **no**.
A typed param would buy nothing the merge doesn't already give us, and it'd
duplicate every renderer's signature. Pass `attribute.class("…")` through
`attrs` and stop.

Conventions that still matter:

- The headless layer *never* sets `class`. It produces semantic/behavior
  attributes only — `class` belongs to the styled layer.
- Caller extras concatenate with the recipe but **don't go through `cn`**.
  Non-conflicting additions (`ml-2 shadow-sm`) just work. `cn` is a plain join
  and does **not** resolve conflicts (see [Class joining](#class-joining-our-cn)),
  so a caller overriding a recipe utility relies on CSS source/layer order, not
  a merge step.
- For *conditional* classes prefer Lustre's `attribute.classes(List(#(String, Bool)))`
  over hand-built strings; it merges identically.

## Class joining (our `cn`)

Upstream shadcn ships every recipe through `cn(...)`, which wraps
[`tailwind-merge`](https://github.com/dcastil/tailwind-merge): it parses utility
names and *drops* earlier conflicts when a later utility of the same property
arrives — e.g. `"border-transparent border-border"` becomes `"border-border"`.
shadcn leans on this because its recipes emit **raw Tailwind utilities**, which
genuinely collide.

**We do too — so we ship our own.** A component's class string has two buckets
(see [AGENTS.md](../AGENTS.md) rule 8, mirroring shadcn's Base UI `style-mira`):
**structural / overridable** utilities are emitted as **raw Tailwind** in the
component's `base` string (`inline-flex items-center justify-center …`, constant
across styles), and only the **themeable surface** (color, radius, rings) goes in
the `cn-*` `@apply` recipe. Because the overridable utilities are raw, a caller's
`class` genuinely collides with them — so `cn` must resolve conflicts, exactly
like shadcn's.

`cn` is backed by **[`gg_cn`](../packages/gg_cn)**, our **pure-Gleam**
`clsx + tailwind-merge` port (no FFI, no Elixir `tails`), so it stays
**identical on JS and the BEAM** — see [vision.md](vision.md) rule 2, "Both
targets, or it doesn't ship." The class trie builds once via `gg_cn.default()`.

The helper lives in **`gg_base_ui/helpers/cn.gleam`** — *not* the ejected styled
layer — so it's **imported, never copied/frozen** into user code. It exposes two
functions:

- `cn(fragments: List(String)) -> String` — clsx-join + tailwind-merge.
- `cn.merge(own:, attrs:) -> List(Attribute)` — the component-authoring helper:
  pulls every `class` value out of `attrs`, folds them through `cn` with the
  component's own classes, and returns one merged `class` attribute.

```gleam
pub fn classes(variant variant: Variant, size size: Size) -> String {
  gva.gva(default: base, resolver: resolve, defaults: [])
  |> gva.with(VariantKey(variant))
  |> gva.with(SizeKey(size))
  |> gva.build
  |> fn(recipe) { cn.cn([recipe]) }
}
```

### Caller-side conflict resolution

A caller's `class` (in `attrs`) must actually override the component's default,
which means the conflicting default has to be **removed** — appending isn't
enough, because the CSS cascade is decided by **stylesheet order**, not by the
order of names in the class attribute. So the component folds the caller's class
in with `cn.merge`, which runs tailwind-merge over `[own, ..caller_classes]`:

```gleam
import gg_base_ui/helpers/cn

pub fn button(variant, size, attrs, children) {
  base_button.button(
    config: base_button.config(),
    attrs: [
      attribute.attribute("data-slot", "button"),
      ..cn.merge(own: classes(variant:, size:), attrs: attrs)
    ],
    children:,
  )
}
```

A caller then just passes the override like any other attribute, and it wins:

```gleam
styled_button.button(
  variant: styled_button.Outline,
  size: styled_button.Medium,
  attrs: [attribute.class("justify-between"), ..rest],   // removes justify-center
  children: [html.text("Spread")],
)
```

This only resolves conflicts against utilities that are **raw in the component**
(rule 8). A utility buried inside a `cn-*` `@apply` recipe is invisible to the
merge engine (and out-specified by the `.style-x .cn-y` selector), so anything a
caller should be able to override stays raw in `base`.

## Limitations

- **NonNative keyboard activation.** Base UI's `useButton` synthesizes
  Space/Enter → click on non-native buttons. We don't yet — callers using
  pattern 3 must attach `on_keydown` themselves. Lift this into the headless
  layer when we have a clean way to dispatch synthetic activation in Lustre.
- **Single-event-handler-per-attribute.** A caller's `on_click` will replace
  any handler the headless layer might attach. Today no headless layer attaches
  any, so this is academic — but if/when one needs to (e.g. focus management),
  we'll need a handler-stacking helper (Base UI's `mergeProps` chains them; we
  don't get that for free).

## Checklist for new components

- [ ] Headless module under
      `packages/gg_base_ui/src/gg_base_ui/<name>/<name>.gleam` exposing
      `Config`, `config()`, `attributes(config, target)`, and the default
      renderer.
- [ ] Thin styled module under `packages/gg_ui/src/gg_ui/ui/<name>.gleam`
      exposing the variant/size types, `classes(...)` (emitting `cn-*` names),
      and the default renderer; add its Tailwind recipe to the shape fragment
      `styles/shapes/<style>/<name>.css`.
- [ ] Add a named convenience renderer (`link`, `tile`, …) for any
      non-default element that's common enough to warrant it. Otherwise
      document pattern 3 and stop.
- [ ] Never set `class` (or `style`) in the headless layer.
- [ ] Use labeled arguments on all public functions.
- [ ] Don't add an `extra` / `extra_class` param — callers pass
      `attribute.class("…")` through `attrs`, and the component folds it in with
      `cn.merge(own:, attrs:)` so overrides resolve via tailwind-merge.
- [ ] Keep overridable structural utilities **raw in `base`**; put only the
      themeable surface in the `cn-*` `@apply` recipe (rule 8). Build the recipe
      with `cn.cn([_])` (clsx + tailwind-merge — see
      [Class joining](#class-joining-our-cn)).
- [ ] If the component has non-`<button>` semantics that need a `Target`-like
      split, mirror the pattern here.

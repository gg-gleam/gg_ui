# gg_icon

[![Package Version](https://img.shields.io/hexpm/v/gg_icon)](https://hex.pm/packages/gg_icon)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gg_icon/)

The **set-agnostic icon interface** for [Lustre](https://lustre.build) — the
shared contract every `gg_icons_*` set (lucide, tabler, heroicons, …) is
generated against. It holds the size scale, the `svg` wrapper, and the authoring
`placeholder`. It imports **no concrete icon set** and ships **no Tailwind**,
keeping it a lean, dual-target (JS + Erlang) foundation.

Part of the [gg_ui](https://github.com/gg-gleam/gg_ui) project. See
[`dev-docs/icons.md`](https://github.com/gg-gleam/gg_ui/blob/main/dev-docs/icons.md)
for the full icon-system design.

```sh
gleam add gg_icon
```

## What's in it

An icon is a Gleam function that emits a Lustre SVG element with its path data
baked in — no npm runtime, tree-shakeable per function, identical on both Lustre
targets. The concrete sets do that emitting; `gg_icon` is the interface they all
call.

### `Size` + `size`

A typed size scale. Each maps to a `cn-icon-size-*` class whose name carries the
`size-` token, so an explicit size defeats a container's
`[&_svg:not([class*='size-'])]` auto-size default (the shadcn idiom). Sizing is
orthogonal to set and variant.

```gleam
import gg_icon/icon

// Default size (whatever the container/CSS decides):
lucide.star([])

// Typed scale → "cn-icon-size-lg":
lucide.star([icon.size(icon.Lg)])

// One-off escape hatch — wins by source order (keep the `size-` token):
lucide.star([attribute.class("size-[18px]")])
```

### `svg`

The shared wrapper every generated icon calls. It's generic over `view_box` and
per-variant `defaults` so it serves stroke *and* fill variants (an outline
variant passes `fill=none stroke=currentColor`; a filled one passes
`fill=currentColor`). Caller `attrs` are appended **last**, so overrides win by
source order. Everything stays `currentColor`, so `color` / `text-*` drive the
colour.

```gleam
icon.svg(
  view_box: "0 0 24 24",
  defaults: [#("fill", "none"), #("stroke", "currentColor"), #("stroke-width", "2")],
  attrs: attrs,
  children: [svg.path([attribute.attribute("d", "m6 9 6 6 6-6")])],
)
```

### `placeholder` + `fallback_box`

`placeholder` is the authoring construct used in registry source — the (future)
CLI transformer rewrites each call to a direct `<shard>.<icon>(attrs)` for the
user's chosen set/variant, so it never reaches a shipped bundle. Until then (and
in any non-transformed runtime) it renders `fallback_box`: a neutral rounded
square marking where an icon would go.

## Consuming a set

You don't usually depend on `gg_icon` directly — you depend on a set that
depends on it, and call the set's generated functions:

```gleam
import gg_icons_lucide/lucide/c as lucide_c

pub fn view() {
  lucide_c.chevron_down([icon.size(icon.Sm)])
}
```

## Licence

MIT

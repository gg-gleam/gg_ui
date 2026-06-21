//// shadcn-flavoured `Avatar` — the **thin** styled layer over the headless
//// `gg_base_ui/avatar`. Mirrors shadcn's parts (`Avatar` / `AvatarImage` /
//// `AvatarFallback`) and its `size` prop, emitting `cn-*` class names whose
//// Tailwind recipe lives in `styles/shapes/<style>/avatar.css`. Behavior (the
//// load/fallback swap) + the markup structure come from the headless layer; this
//// layer only owns appearance and the `data-slot` / `data-size` / `data-shape`
//// hooks.
////
//// **Two divergences from shadcn**, both additive:
//// - an extra-small `Xs` size, baked in for chip-sized avatars (shadcn stops at
////   `sm`/`size-6` — too large inside a chip);
//// - a `Shape` axis. shadcn avatars are always `rounded-full`; we keep `Circle`
////   as the default but also offer `Rounded` (rounded-corner square, what fits a
////   chip) and `Squircle` (the modern superellipse — `corner-shape: squircle` as
////   a progressive enhancement over the `border-radius` fallback, so it degrades
////   to a rounded square where unsupported).
////
//// **Facade (rule 2).** `Size` / `Shape` are gg_ui's own types — the headless
//// layer has no size/shape concept (it's pure structure), so `data-*` + the
//// `cn-*` recipe carry them entirely; there's no `*_to_base` to map. A consumer
//// imports **only** `gg_ui/ui/avatar`.
////
//// shadcn renders `group/avatar` + `data-size` on the root so the parts can
//// react to the size via `group-data-[size=*]/avatar:` — the marker rides in the
//// markup, its consumers live in the `@apply` recipe (the group-marker idiom).

import gg_base_ui/avatar/avatar as base_avatar
import gg_ui/helpers/cn
import gva
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html

/// Avatar size. `Xs` is `size-5` (chip-sized), `Sm` `size-6`, `Default`
/// `size-8`, `Lg` `size-10`.
pub type Size {
  Xs
  Sm
  Default
  Lg
}

/// Avatar shape. `Circle` (shadcn's default, `rounded-full`); `Rounded` (a
/// rounded-corner square — what sits well inside a chip); `Squircle` (the modern
/// superellipse via `corner-shape: squircle`, falling back to a rounded square).
pub type Shape {
  Circle
  Rounded
  Squircle
}

type Key {
  SizeKey(Size)
  ShapeKey(Shape)
}

const base = "cn-avatar"

/// The `cn-*` recipe for the root at `size` + `shape` — `gva` assembles
/// `cn-avatar` + `cn-avatar-size-*` + `cn-avatar-shape-*`, `cn` joins them.
pub fn classes(size size: Size, shape shape: Shape) -> String {
  gva.gva(default: base, resolver: resolve, defaults: [])
  |> gva.with(SizeKey(size))
  |> gva.with(ShapeKey(shape))
  |> gva.build
  |> fn(recipe) { cn.cn([recipe]) }
}

/// The avatar container (shadcn's `Avatar`). Carries `data-slot=avatar`,
/// `data-size`, `data-shape`, and the `group/avatar` marker. Compose an `image`
/// and a `fallback` inside it.
pub fn avatar(
  size size: Size,
  shape shape: Shape,
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  base_avatar.root(
    attrs: [
      attribute.attribute("data-slot", "avatar"),
      attribute.attribute("data-size", size_value(size)),
      attribute.attribute("data-shape", shape_value(shape)),
      attribute.class(classes(size:, shape:)),
      attribute.class("group/avatar"),
      ..attrs
    ],
    children:,
  )
}

/// The image (shadcn's `AvatarImage`) — `data-slot=avatar-image` + the
/// `cn-avatar-image` recipe. Stacked over the `fallback`; on load failure the
/// headless observer hides it so the fallback shows through.
pub fn image(
  src src: String,
  alt alt: String,
  attrs attrs: List(Attribute(msg)),
) -> Element(msg) {
  base_avatar.image(src:, alt:, attrs: [
    attribute.attribute("data-slot", "avatar-image"),
    attribute.class(cn.cn(["cn-avatar-image"])),
    ..attrs
  ])
}

/// The fallback (shadcn's `AvatarFallback`) — `data-slot=avatar-fallback` + the
/// `cn-avatar-fallback` recipe (centred initials/icon on a muted ground, its
/// corners inheriting the root shape).
pub fn fallback(
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  base_avatar.fallback(
    attrs: [
      attribute.attribute("data-slot", "avatar-fallback"),
      attribute.class(cn.cn(["cn-avatar-fallback"])),
      ..attrs
    ],
    children:,
  )
}

/// A status indicator pinned to the avatar's corner (shadcn's `AvatarBadge`) —
/// an online dot, or a tiny status icon as `children`. Place it as a sibling of
/// the `image`/`fallback` inside `avatar`; it sizes itself off the avatar's
/// `data-size`. Defaults to the primary colour — pass a colour override in
/// `attrs` for e.g. an online green.
pub fn badge(
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  html.span(
    [
      attribute.attribute("data-slot", "avatar-badge"),
      attribute.class(cn.cn(["cn-avatar-badge"])),
      ..attrs
    ],
    children,
  )
}

/// A row of overlapping avatars (shadcn's `AvatarGroup`) — each gets a ring so
/// the overlap reads cleanly. Carries the `group/avatar-group` marker so a
/// trailing `group_count` sizes off the avatars within. `children` is the
/// `avatar`s followed by an optional `group_count`.
pub fn group(
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  html.div(
    [
      attribute.attribute("data-slot", "avatar-group"),
      attribute.class(cn.cn(["cn-avatar-group"])),
      attribute.class("group/avatar-group"),
      ..attrs
    ],
    children,
  )
}

/// The trailing overflow count at the end of a `group` (shadcn's
/// `AvatarGroupCount`) — `children` is the `+N` text or an icon. Sizes off the
/// group's avatars.
pub fn group_count(
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  html.div(
    [
      attribute.attribute("data-slot", "avatar-group-count"),
      attribute.class(cn.cn(["cn-avatar-group-count"])),
      ..attrs
    ],
    children,
  )
}

fn resolve(key: Key) -> String {
  case key {
    SizeKey(size) -> size_class(size)
    ShapeKey(shape) -> shape_class(shape)
  }
}

fn size_class(size: Size) -> String {
  case size {
    Xs -> "cn-avatar-size-xs"
    Sm -> "cn-avatar-size-sm"
    Default -> "cn-avatar-size-default"
    Lg -> "cn-avatar-size-lg"
  }
}

fn size_value(size: Size) -> String {
  case size {
    Xs -> "xs"
    Sm -> "sm"
    Default -> "default"
    Lg -> "lg"
  }
}

fn shape_class(shape: Shape) -> String {
  case shape {
    Circle -> "cn-avatar-shape-circle"
    Rounded -> "cn-avatar-shape-rounded"
    Squircle -> "cn-avatar-shape-squircle"
  }
}

fn shape_value(shape: Shape) -> String {
  case shape {
    Circle -> "circle"
    Rounded -> "rounded"
    Squircle -> "squircle"
  }
}

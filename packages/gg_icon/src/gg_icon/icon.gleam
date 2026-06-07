//// gg_icon — the set-agnostic icon interface every `gg_icons_*` package builds
//// on. It holds the size scale, the shared `svg` wrapper (generic over `viewBox`
//// + per-variant defaults, so it serves stroke *and* fill variants), and the
//// authoring `placeholder`. It never imports a concrete icon set and ships no
//// Tailwind — keeping it a lean, dual-target foundation.
////
//// See `dev-docs/icons.md` in the gg_ui repo for the full design.

import gleam/list
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/svg as svg_el

// --- Size scale --------------------------------------------------------------

/// Typed icon sizes. Each maps to a `cn-icon-size-*` class whose name carries
/// the `size-` token, so an explicit size defeats a container's
/// `[&_svg:not([class*='size-'])]` default (the idiom shadcn and our own button
/// recipes already use). Sizing is fully orthogonal to set/variant.
pub type Size {
  Sm
  Md
  Lg
}

/// A class attribute selecting a named size. Pass it in an icon's `attrs`:
/// `lucide.star([icon.size(icon.Lg)])`. For a one-off, pass a raw
/// `attribute.class("size-[18px]")` instead — it wins by source order.
pub fn size(size: Size) -> Attribute(msg) {
  attribute.class(size_class(size))
}

fn size_class(size: Size) -> String {
  case size {
    Sm -> "cn-icon-size-sm"
    Md -> "cn-icon-size-md"
    Lg -> "cn-icon-size-lg"
  }
}

// --- The shared svg wrapper --------------------------------------------------

/// Build an icon `<svg>`. Generated icon functions call this with their
/// variant's `view_box` + `defaults` (e.g. `fill=none stroke=currentColor` for
/// an outline variant, `fill=currentColor` for a filled one). `attrs` is
/// appended **last** so caller overrides win by source order. Everything stays
/// `currentColor`, so `color` / `text-*` drive the colour and `size` /
/// `size-*` drive the size.
pub fn svg(
  view_box view_box: String,
  defaults defaults: List(#(String, String)),
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  svg_el.svg(
    list.flatten([
      [
        attribute.class("cn-icon"),
        attribute.attribute("viewBox", view_box),
        attribute.attribute("data-slot", "icon"),
        attribute.attribute("aria-hidden", "true"),
      ],
      list.map(defaults, fn(d) { attribute.attribute(d.0, d.1) }),
      attrs,
    ]),
    children,
  )
}

// --- Placeholder (authoring construct) ---------------------------------------

/// Authoring placeholder used in registry source. The (future) CLI transformer
/// replaces each call with a direct `<shard>.<icon>(attrs)` for the user's
/// chosen set/variant, so this never reaches a shipped bundle. Until then — and
/// in any non-transformed runtime — it renders a neutral fallback box.
///
/// Storybook's live preview will inject a resolver here so embedded icons
/// (a dialog-close `x`) switch with the toolbar; that wiring lands with the
/// `apps/storybook` demo catalog and keeps `gg_icon` set-agnostic.
pub fn placeholder(
  lucide _lucide: String,
  tabler _tabler: String,
  attrs attrs: List(Attribute(msg)),
) -> Element(msg) {
  fallback_box(attrs)
}

/// A neutral rounded square — the placeholder's no-resolver fallback, and a
/// visible "icon would go here" marker in un-transformed previews.
pub fn fallback_box(attrs: List(Attribute(msg))) -> Element(msg) {
  svg(
    view_box: "0 0 24 24",
    defaults: [
      #("fill", "none"),
      #("stroke", "currentColor"),
      #("stroke-width", "2"),
      #("stroke-linecap", "round"),
      #("stroke-linejoin", "round"),
    ],
    attrs: attrs,
    children: [
      svg_el.path([attribute.attribute("d", "M4 4h16v16H4z")]),
    ],
  )
}

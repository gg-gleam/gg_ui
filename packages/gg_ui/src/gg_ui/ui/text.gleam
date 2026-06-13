//// `Text` — typed, tokenized typography for app UIs. **This is a deliberate
//// divergence from shadcn**, which ships *no* Text component (you copy utility
//// recipes). gg_ui ships one because in Lustre hand-writing utility strings on
//// `html.h1` is awkward, and a *closed, typed* API enforces a single type scale
//// + color palette: app text can't drift off-token or off-scale. There is **no
//// headless layer** — text has no behavior or ARIA beyond the element you render
//// it as (so, like `icon`, it lives only here).
////
//// **Enforcement is in the type system, not just convention.** The named
//// helpers take `List(Attr(msg))`, an **opaque** type whose only constructors
//// are `id` / `aria` / `data` — there is deliberately **no `class`/`style`
//// constructor**, so a styling override on the blessed path *cannot compile*.
//// a11y/structural attrs still work. When you genuinely need to go off-road
//// (raw class, a one-off style), that's the explicit, visible escape hatch:
//// merge the open `attributes(style, color)` list onto a bare element yourself
//// (`html.h1([attribute.class("…"), ..text.attributes(H1, Foreground)], …)`) —
//// off-road is *possible* but never *accidental*.
////
//// Like the rest of gg_ui it emits `cn-*` names; the Tailwind recipe lives
//// per-shape in `styles/shapes/<style>/text.css`. It is **element-agnostic**:
//// the visual `Style` is decoupled from the rendered element. The named helpers
//// (`text.h1`, …) default to a sensible tag; for "h3 *look* on an `<h2>`", merge
//// `attributes(H3, …)` onto any element — the asChild / useRender analogue.

import gg_ui/helpers/cn
import gleam/list
import gva
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html

/// A **safe** attribute for the `text.*` helpers. Opaque, so the only values
/// that exist are the ones the constructors below mint — `id` / `aria` / `data`.
/// There is **no `class` or `style` constructor**, which is what makes a
/// non-tokenized styling override *impossible to express* on the helper path
/// (the enforcement the open `attributes` escape hatch deliberately relaxes).
pub opaque type Attr(msg) {
  Attr(Attribute(msg))
}

/// `id="…"` — for `aria-labelledby`, anchors, etc.
pub fn id(value: String) -> Attr(msg) {
  Attr(attribute.id(value))
}

/// `aria-<name>="…"` (pass `name` without the `aria-` prefix), e.g.
/// `aria("label", "Page title")`.
pub fn aria(name name: String, value value: String) -> Attr(msg) {
  Attr(attribute.attribute("aria-" <> name, value))
}

/// `data-<name>="…"` (pass `name` without the `data-` prefix).
pub fn data(name name: String, value value: String) -> Attr(msg) {
  Attr(attribute.attribute("data-" <> name, value))
}

fn to_attribute(attr: Attr(msg)) -> Attribute(msg) {
  let Attr(inner) = attr
  inner
}

/// The closed type scale — each member bundles size + weight + leading +
/// tracking + family as ONE decision. Color is a **separate** axis (below): a
/// style never bakes in a color, so shadcn's "Lead" = `Lead` + `Muted`. Weight
/// variants are named *members* (`BodyStrong`), never a free `weight` axis —
/// that closedness is what actually keeps every piece of text on one scale.
pub type Style {
  Display
  H1
  H2
  H3
  H4
  Lead
  Large
  Body
  BodyStrong
  Small
  Caption
}

/// The color axis — semantic tokens only, so text rides the Base Color / Theme
/// axes (dark mode + accent swaps for free). No raw colors, by design.
pub type Color {
  Foreground
  Muted
  Primary
  Destructive
}

type Key {
  StyleKey(Style)
  ColorKey(Color)
}

const base = "cn-text"

/// The `cn-*` recipe for a style + color. Exposed for parity with `button`;
/// most callers use the helpers or `attributes` instead.
pub fn classes(style style: Style, color color: Color) -> String {
  gva.gva(default: base, resolver: resolve, defaults: [])
  |> gva.with(StyleKey(style))
  |> gva.with(ColorKey(color))
  |> gva.build
  |> fn(recipe) { cn.cn([recipe]) }
}

/// The styled attributes, **element-agnostic** — merge onto any element to apply
/// a text style without committing to its default tag (the asChild analogue):
/// `html.h2(text.attributes(H3, Muted), [..])`.
///
/// This is also the **escape hatch**: it returns the open `Attribute(msg)` list
/// (not the curated `Attr`), so this is where — and the only place — a caller
/// may knowingly mix in raw `attribute.class`/`style`. Off-road by explicit
/// opt-in, never by accident on the `text.*` helpers.
pub fn attributes(
  style style: Style,
  color color: Color,
) -> List(Attribute(msg)) {
  [
    attribute.attribute("data-slot", "text"),
    attribute.class(classes(style:, color:)),
  ]
}

// --- named helpers — sugar over `attributes`, each with a default element ----
// Pass `color` explicitly (everything typed); `attrs` is the curated `Attr`
// list (id/aria/data only). To override the element, use `attributes` on the
// tag you want instead of the helper.

pub fn display(
  color color: Color,
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.h1, Display, color, attrs, children)
}

pub fn h1(
  color color: Color,
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.h1, H1, color, attrs, children)
}

pub fn h2(
  color color: Color,
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.h2, H2, color, attrs, children)
}

pub fn h3(
  color color: Color,
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.h3, H3, color, attrs, children)
}

pub fn h4(
  color color: Color,
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.h4, H4, color, attrs, children)
}

pub fn lead(
  color color: Color,
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.p, Lead, color, attrs, children)
}

pub fn large(
  color color: Color,
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.div, Large, color, attrs, children)
}

pub fn body(
  color color: Color,
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.p, Body, color, attrs, children)
}

pub fn body_strong(
  color color: Color,
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.p, BodyStrong, color, attrs, children)
}

pub fn small(
  color color: Color,
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.small, Small, color, attrs, children)
}

pub fn caption(
  color color: Color,
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.span, Caption, color, attrs, children)
}

// --- internals ---------------------------------------------------------------

fn el(
  element: fn(List(Attribute(msg)), List(Element(msg))) -> Element(msg),
  style: Style,
  color: Color,
  attrs: List(Attr(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  // The recipe attrs are ours; the caller's `Attr`s are unwrapped to their safe
  // inner `Attribute` (no class/style can have been constructed).
  let safe = list.map(attrs, to_attribute)
  element(list.flatten([attributes(style:, color:), safe]), children)
}

fn resolve(key: Key) -> String {
  case key {
    StyleKey(style) -> style_class(style)
    ColorKey(color) -> color_class(color)
  }
}

fn style_class(style: Style) -> String {
  case style {
    Display -> "cn-text-display"
    H1 -> "cn-text-h1"
    H2 -> "cn-text-h2"
    H3 -> "cn-text-h3"
    H4 -> "cn-text-h4"
    Lead -> "cn-text-lead"
    Large -> "cn-text-large"
    Body -> "cn-text-body"
    BodyStrong -> "cn-text-body-strong"
    Small -> "cn-text-small"
    Caption -> "cn-text-caption"
  }
}

fn color_class(color: Color) -> String {
  case color {
    Foreground -> "cn-text-color-foreground"
    Muted -> "cn-text-color-muted"
    Primary -> "cn-text-color-primary"
    Destructive -> "cn-text-color-destructive"
  }
}

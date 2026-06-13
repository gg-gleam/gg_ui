//// `Text` — typed, tokenized typography for app UIs. **A deliberate divergence
//// from shadcn**, which ships no typography component (only copy-paste recipes).
//// gg_ui ships a real one because in Lustre hand-writing utility strings on
//// `html.h1` is awkward, and a *closed, typed* API enforces a single type scale
//// + palette. No headless layer — text has no behavior/ARIA beyond the element.
////
//// ## The API mirrors Lustre: `text.h1(attrs, children)`
////
//// Like every Lustre element (`html.h1(attrs, children)`), a `text` helper takes
//// a **`List(Attr(msg))`** then children. The common case is an empty list; each
//// `Attr` is one typed, tokenized decision:
////
//// ```gleam
//// text.h1([], [html.text("Heading")])                          // defaults
//// text.h1([text.color(text.Muted), text.align(text.Center)], […])
//// text.h1([text.render_as(html.h3)], […])    // H1 look on a semantic <h3>
//// text.h1([text.id("intro"), text.on_click(Msg)], […])         // a11y / events
//// ```
////
//// `Attr` is **opaque** — every constructor is a tokenized modifier, a curated
//// a11y/event attr, or `render_as`. There is deliberately **no `class`/`style`
//// constructor**, so off-token / off-scale text can't be expressed (and no
//// tailwind-merge is needed). `color` defaults to `Foreground`; other modifiers
//// default to "normal" (omit the attr). `render_as` swaps the element (a real
//// Lustre element); without it, helpers default `h1–h4` → `<h1>–<h4>` and
//// `h5–h7` → `<p>` (a body-sized `<h6>` would pollute the a11y outline).
////
//// Emits `cn-*` names; the per-shape type scale lives in
//// `styles/shapes/<style>/text.css`, the shape-invariant modifiers in
//// `styles/text.css`.

import gg_ui/helpers/cn
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

// --- the type scale ----------------------------------------------------------

/// The closed, **numeric** type scale — `h1…h7`, the way a designer names a text
/// style in Figma ("set h5, it maps to the DS"). Each member bundles size +
/// weight + leading + tracking + family as ONE decision. **Weight variants are
/// baked members** (`H4M` = medium, `H4B` = bold) — a curated allow-list, NOT a
/// free `weight` axis. Add a member only when the design system defines it.
pub type Style {
  H1
  H2
  H3
  H4
  H4M
  H4B
  H5
  H5M
  H6
  H6M
  H6B
  H7
}

// --- tokenized modifier axes -------------------------------------------------

/// Color — semantic tokens only, so text rides the Base Color / Theme axes.
/// `Foreground` is the default (omit `text.color`).
pub type Color {
  Foreground
  Muted
  Primary
  Destructive
}

/// Logical text alignment.
pub type Align {
  Start
  Center
  End
}

/// Letter-case transform.
pub type Transform {
  Uppercase
  Lowercase
  Capitalize
}

/// Text decoration.
pub type Decoration {
  Underline
  LineThrough
}

/// Truncation. `Ellipsis` = single line; `Lines(n)` = clamp to n lines
/// (clamped to 1–6).
pub type Truncate {
  Ellipsis
  Lines(Int)
}

/// `white-space`.
pub type Whitespace {
  NoWrap
  Pre
  PreLine
  PreWrap
}

/// `word-break` / `overflow-wrap`.
pub type WordBreak {
  BreakAll
  BreakWord
  KeepAll
}

/// `text-wrap` for balanced / pretty line breaking.
pub type Wrap {
  Balance
  Pretty
}

/// Text opacity steps (`100%` is the default — omit `text.opacity`).
pub type Opacity {
  O90
  O80
  O70
  O60
  O50
}

// --- the attribute vocabulary ------------------------------------------------

/// A single typed decision for a `text.*` helper — a tokenized modifier, a
/// curated a11y/event attribute, or `render_as`. **Opaque, with no `class`/
/// `style` constructor**, so an off-token styling override can't be expressed.
pub opaque type Attr(msg) {
  AttrColor(Color)
  AttrAlign(Align)
  AttrTransform(Transform)
  AttrDecoration(Decoration)
  AttrItalic
  AttrTruncate(Truncate)
  AttrWhitespace(Whitespace)
  AttrWordBreak(WordBreak)
  AttrWrap(Wrap)
  AttrOpacity(Opacity)
  AttrSelectable(Bool)
  AttrRenderAs(fn(List(Attribute(msg)), List(Element(msg))) -> Element(msg))
  AttrHtml(Attribute(msg))
}

/// Override the text color (default `Foreground`).
pub fn color(value: Color) -> Attr(msg) {
  AttrColor(value)
}

/// Set the text alignment (default `Start`).
pub fn align(value: Align) -> Attr(msg) {
  AttrAlign(value)
}

/// Apply a letter-case transform.
pub fn transform(value: Transform) -> Attr(msg) {
  AttrTransform(value)
}

/// Apply a text decoration.
pub fn decoration(value: Decoration) -> Attr(msg) {
  AttrDecoration(value)
}

/// Render italic.
pub fn italic() -> Attr(msg) {
  AttrItalic
}

/// Truncate with an ellipsis (single line) or clamp to N lines.
pub fn truncate(value: Truncate) -> Attr(msg) {
  AttrTruncate(value)
}

/// Set `white-space`.
pub fn whitespace(value: Whitespace) -> Attr(msg) {
  AttrWhitespace(value)
}

/// Set `word-break` / `overflow-wrap`.
pub fn word_break(value: WordBreak) -> Attr(msg) {
  AttrWordBreak(value)
}

/// Set `text-wrap` (balanced / pretty line breaking).
pub fn wrap(value: Wrap) -> Attr(msg) {
  AttrWrap(value)
}

/// Reduce text opacity (default fully opaque).
pub fn opacity(value: Opacity) -> Attr(msg) {
  AttrOpacity(value)
}

/// Toggle user text selection (default `True`). `selectable(False)` adds
/// `select-none`.
pub fn selectable(value: Bool) -> Attr(msg) {
  AttrSelectable(value)
}

/// Render the style on a *different* element — a real Lustre element such as
/// `html.h3` (the asChild / `useRender` analogue). Without it, the helper's
/// natural tag is used.
pub fn render_as(
  element: fn(List(Attribute(msg)), List(Element(msg))) -> Element(msg),
) -> Attr(msg) {
  AttrRenderAs(element)
}

/// `id="…"` — for `aria-labelledby`, anchors, etc.
pub fn id(value: String) -> Attr(msg) {
  AttrHtml(attribute.id(value))
}

/// `aria-<name>="…"` (pass `name` without the `aria-` prefix).
pub fn aria(name name: String, value value: String) -> Attr(msg) {
  AttrHtml(attribute.attribute("aria-" <> name, value))
}

/// `data-<name>="…"` (pass `name` without the `data-` prefix).
pub fn data(name name: String, value value: String) -> Attr(msg) {
  AttrHtml(attribute.attribute("data-" <> name, value))
}

/// A click handler (for interactive text). More event constructors can be added
/// the same way; raw `Attribute`s are deliberately not accepted.
pub fn on_click(msg: msg) -> Attr(msg) {
  AttrHtml(event.on_click(msg))
}

// --- named helpers — h1–h4 headings, h5–h7 neutral `<p>` ----------------------

pub fn h1(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(H1, html.h1, attrs, children)
}

pub fn h2(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(H2, html.h2, attrs, children)
}

pub fn h3(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(H3, html.h3, attrs, children)
}

pub fn h4(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(H4, html.h4, attrs, children)
}

pub fn h4_m(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(H4M, html.h4, attrs, children)
}

pub fn h4_b(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(H4B, html.h4, attrs, children)
}

pub fn h5(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(H5, html.p, attrs, children)
}

pub fn h5_m(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(H5M, html.p, attrs, children)
}

pub fn h6(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(H6, html.p, attrs, children)
}

pub fn h6_m(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(H6M, html.p, attrs, children)
}

pub fn h6_b(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(H6B, html.p, attrs, children)
}

pub fn h7(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(H7, html.p, attrs, children)
}

// --- internals ---------------------------------------------------------------

type Resolved(msg) {
  Resolved(
    color: Color,
    classes: List(String),
    render_as: Option(
      fn(List(Attribute(msg)), List(Element(msg))) -> Element(msg),
    ),
    html: List(Attribute(msg)),
  )
}

const base = "cn-text"

fn render(
  style: Style,
  default_element: fn(List(Attribute(msg)), List(Element(msg))) -> Element(msg),
  attrs: List(Attr(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  let r = resolve(attrs)
  let element = case r.render_as {
    Some(custom) -> custom
    None -> default_element
  }
  let class =
    cn.cn([base, style_class(style), color_class(r.color), ..r.classes])
  let html_attrs = [
    attribute.attribute("data-slot", "text"),
    attribute.class(class),
    ..list.reverse(r.html)
  ]
  element(html_attrs, children)
}

// Fold the attrs into resolved color / modifier classes / element / html attrs.
fn resolve(attrs: List(Attr(msg))) -> Resolved(msg) {
  use acc, attr <- list.fold(attrs, Resolved(Foreground, [], None, []))
  case attr {
    AttrColor(c) -> Resolved(..acc, color: c)
    AttrRenderAs(e) -> Resolved(..acc, render_as: Some(e))
    AttrHtml(a) -> Resolved(..acc, html: [a, ..acc.html])
    AttrItalic -> push(acc, "cn-text-italic")
    AttrSelectable(False) -> push(acc, "cn-text-select-none")
    AttrSelectable(True) -> acc
    AttrAlign(a) -> push(acc, align_class(a))
    AttrTransform(t) -> push(acc, transform_class(t))
    AttrDecoration(d) -> push(acc, decoration_class(d))
    AttrTruncate(t) -> push(acc, truncate_class(t))
    AttrWhitespace(w) -> push(acc, whitespace_class(w))
    AttrWordBreak(w) -> push(acc, word_break_class(w))
    AttrWrap(w) -> push(acc, wrap_class(w))
    AttrOpacity(o) -> push(acc, opacity_class(o))
  }
}

fn push(acc: Resolved(msg), class: String) -> Resolved(msg) {
  Resolved(..acc, classes: [class, ..acc.classes])
}

fn style_class(style: Style) -> String {
  case style {
    H1 -> "cn-text-h1"
    H2 -> "cn-text-h2"
    H3 -> "cn-text-h3"
    H4 -> "cn-text-h4"
    H4M -> "cn-text-h4-m"
    H4B -> "cn-text-h4-b"
    H5 -> "cn-text-h5"
    H5M -> "cn-text-h5-m"
    H6 -> "cn-text-h6"
    H6M -> "cn-text-h6-m"
    H6B -> "cn-text-h6-b"
    H7 -> "cn-text-h7"
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

fn align_class(align: Align) -> String {
  case align {
    Start -> "cn-text-align-start"
    Center -> "cn-text-align-center"
    End -> "cn-text-align-end"
  }
}

fn transform_class(transform: Transform) -> String {
  case transform {
    Uppercase -> "cn-text-transform-uppercase"
    Lowercase -> "cn-text-transform-lowercase"
    Capitalize -> "cn-text-transform-capitalize"
  }
}

fn decoration_class(decoration: Decoration) -> String {
  case decoration {
    Underline -> "cn-text-decoration-underline"
    LineThrough -> "cn-text-decoration-line-through"
  }
}

fn truncate_class(truncate: Truncate) -> String {
  case truncate {
    Ellipsis -> "cn-text-ellipsis"
    Lines(n) -> "cn-text-clamp-" <> int.to_string(int.clamp(n, 1, 6))
  }
}

fn whitespace_class(whitespace: Whitespace) -> String {
  case whitespace {
    NoWrap -> "cn-text-whitespace-nowrap"
    Pre -> "cn-text-whitespace-pre"
    PreLine -> "cn-text-whitespace-pre-line"
    PreWrap -> "cn-text-whitespace-pre-wrap"
  }
}

fn word_break_class(word_break: WordBreak) -> String {
  case word_break {
    BreakAll -> "cn-text-break-all"
    BreakWord -> "cn-text-break-word"
    KeepAll -> "cn-text-keep-all"
  }
}

fn wrap_class(wrap: Wrap) -> String {
  case wrap {
    Balance -> "cn-text-wrap-balance"
    Pretty -> "cn-text-wrap-pretty"
  }
}

fn opacity_class(opacity: Opacity) -> String {
  case opacity {
    O90 -> "cn-text-opacity-90"
    O80 -> "cn-text-opacity-80"
    O70 -> "cn-text-opacity-70"
    O60 -> "cn-text-opacity-60"
    O50 -> "cn-text-opacity-50"
  }
}

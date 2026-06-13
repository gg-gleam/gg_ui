//// `Text` — typed, tokenized typography for app UIs. **A deliberate divergence
//// from shadcn**, which ships no typography component (only copy-paste recipes).
//// gg_ui ships a real one because in Lustre hand-writing utility strings on
//// `html.h1` is awkward, and a *closed, typed* API enforces a single type scale
//// + palette. No headless layer — text has no behavior/ARIA beyond the element.
////
//// ## The API: a `Props` record of named, tokenized keys
////
//// Every styling decision is a **named field** on `Props`, each a closed enum
//// (or `Option` of one), all defaulted by `props()`. Override with Gleam
//// record-update:
////
//// ```gleam
//// text.h5(text.props(), [html.text("Subtitle")])           // defaults
//// text.h5(
////   text.Props(..text.props(), color: text.Muted, align: text.Center),
////   [html.text("Subtitle")],
//// )
//// ```
////
//// There is **no `class`/`style` field anywhere**, so off-token / off-scale text
//// can't be expressed — the consistency guarantee a recipe page can only suggest
//// (and why no tailwind-merge is needed). Two escape valves, both typed:
////   - `render_as: Some(html.h3)` — render the style on a *different* element (a
////     real Lustre element), e.g. an H1 look on a semantic `<h3>`. Default `None`
////     uses the helper's natural tag.
////   - `html_attrs: [text.id(…), text.aria(…), text.on_click(…)]` — a **curated**
////     list (id / aria / data / events only — still no `class`) for a11y, hooks,
////     and interaction.
////
//// It emits `cn-*` names; the per-shape type scale lives in
//// `styles/shapes/<style>/text.css`, the shape-invariant modifiers in
//// `styles/text.css`. Element default: `h1–h4` are headings, `h5–h7` neutral
//// `<p>` (a body-sized `<h6>` would pollute the a11y outline).

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

// --- tokenized modifier axes (each a named `Props` field) --------------------

/// Color — semantic tokens only, so text rides the Base Color / Theme axes.
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

/// Text opacity steps (`100%` is the default — leave `opacity: None`).
pub type Opacity {
  O90
  O80
  O70
  O60
  O50
}

// --- curated html attributes (no class/style) --------------------------------

/// A **safe** HTML attribute for `Props.html_attrs`. Opaque: the only values are
/// the ones the constructors below mint — `id` / `aria` / `data` / `on_click`.
/// There is **no `class`/`style` constructor**, so the escape channel can't
/// reintroduce a non-tokenized styling override.
pub opaque type Attr(msg) {
  Attr(Attribute(msg))
}

/// `id="…"` — for `aria-labelledby`, anchors, etc.
pub fn id(value: String) -> Attr(msg) {
  Attr(attribute.id(value))
}

/// `aria-<name>="…"` (pass `name` without the `aria-` prefix).
pub fn aria(name name: String, value value: String) -> Attr(msg) {
  Attr(attribute.attribute("aria-" <> name, value))
}

/// `data-<name>="…"` (pass `name` without the `data-` prefix).
pub fn data(name name: String, value value: String) -> Attr(msg) {
  Attr(attribute.attribute("data-" <> name, value))
}

/// A click handler (for interactive text). More event constructors can be added
/// the same way; raw `Attribute`s are deliberately not accepted.
pub fn on_click(msg: msg) -> Attr(msg) {
  Attr(event.on_click(msg))
}

// --- props -------------------------------------------------------------------

/// The full, named configuration for a `text.*` element. Every field is a
/// tokenized key with a default (see `props`); override via record-update. There
/// is intentionally no `class`/`style` field.
pub type Props(msg) {
  Props(
    color: Color,
    align: Align,
    transform: Option(Transform),
    decoration: Option(Decoration),
    italic: Bool,
    truncate: Option(Truncate),
    whitespace: Option(Whitespace),
    word_break: Option(WordBreak),
    wrap: Option(Wrap),
    opacity: Option(Opacity),
    selectable: Bool,
    /// Render the style on a different element (a real Lustre element such as
    /// `html.h3`). `None` = the helper's natural tag.
    render_as: Option(
      fn(List(Attribute(msg)), List(Element(msg))) -> Element(msg),
    ),
    /// Curated a11y / data / event attributes (no class/style).
    html_attrs: List(Attr(msg)),
  )
}

/// The default props: `Foreground`, `Start`, no modifiers, selectable, natural
/// element, no extra attrs. Start every override from here:
/// `Props(..text.props(), color: text.Muted)`.
pub fn props() -> Props(msg) {
  Props(
    color: Foreground,
    align: Start,
    transform: None,
    decoration: None,
    italic: False,
    truncate: None,
    whitespace: None,
    word_break: None,
    wrap: None,
    opacity: None,
    selectable: True,
    render_as: None,
    html_attrs: [],
  )
}

// --- named helpers — h1–h4 headings, h5–h7 neutral `<p>` ----------------------

pub fn h1(props: Props(msg), children: List(Element(msg))) -> Element(msg) {
  render(H1, html.h1, props, children)
}

pub fn h2(props: Props(msg), children: List(Element(msg))) -> Element(msg) {
  render(H2, html.h2, props, children)
}

pub fn h3(props: Props(msg), children: List(Element(msg))) -> Element(msg) {
  render(H3, html.h3, props, children)
}

pub fn h4(props: Props(msg), children: List(Element(msg))) -> Element(msg) {
  render(H4, html.h4, props, children)
}

pub fn h4_m(props: Props(msg), children: List(Element(msg))) -> Element(msg) {
  render(H4M, html.h4, props, children)
}

pub fn h4_b(props: Props(msg), children: List(Element(msg))) -> Element(msg) {
  render(H4B, html.h4, props, children)
}

pub fn h5(props: Props(msg), children: List(Element(msg))) -> Element(msg) {
  render(H5, html.p, props, children)
}

pub fn h5_m(props: Props(msg), children: List(Element(msg))) -> Element(msg) {
  render(H5M, html.p, props, children)
}

pub fn h6(props: Props(msg), children: List(Element(msg))) -> Element(msg) {
  render(H6, html.p, props, children)
}

pub fn h6_m(props: Props(msg), children: List(Element(msg))) -> Element(msg) {
  render(H6M, html.p, props, children)
}

pub fn h6_b(props: Props(msg), children: List(Element(msg))) -> Element(msg) {
  render(H6B, html.p, props, children)
}

pub fn h7(props: Props(msg), children: List(Element(msg))) -> Element(msg) {
  render(H7, html.p, props, children)
}

// --- internals ---------------------------------------------------------------

fn render(
  style: Style,
  default_element: fn(List(Attribute(msg)), List(Element(msg))) -> Element(msg),
  props: Props(msg),
  children: List(Element(msg)),
) -> Element(msg) {
  let element = case props.render_as {
    Some(custom) -> custom
    None -> default_element
  }
  let attrs = [
    attribute.attribute("data-slot", "text"),
    attribute.class(classes(style, props)),
    ..list.map(props.html_attrs, to_attribute)
  ]
  element(attrs, children)
}

fn to_attribute(attr: Attr(msg)) -> Attribute(msg) {
  let Attr(inner) = attr
  inner
}

const base = "cn-text"

fn classes(style: Style, p: Props(msg)) -> String {
  cn.cn([
    base,
    style_class(style),
    color_class(p.color),
    align_class(p.align),
    opt(p.transform, transform_class),
    opt(p.decoration, decoration_class),
    flag(p.italic, "cn-text-italic"),
    opt(p.truncate, truncate_class),
    opt(p.whitespace, whitespace_class),
    opt(p.word_break, word_break_class),
    opt(p.wrap, wrap_class),
    opt(p.opacity, opacity_class),
    flag(!p.selectable, "cn-text-select-none"),
  ])
}

// Resolve an optional modifier to its class, or "" when absent (cn drops it).
fn opt(value: Option(a), to_class: fn(a) -> String) -> String {
  case value {
    Some(v) -> to_class(v)
    None -> ""
  }
}

fn flag(on: Bool, class: String) -> String {
  case on {
    True -> class
    False -> ""
  }
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

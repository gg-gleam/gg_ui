//// `Text` — typed, tokenized typography for app UIs. **A deliberate divergence
//// from shadcn**, which ships no typography component (only copy-paste recipes).
//// gg_ui ships a real one because in Lustre hand-writing utility strings on
//// `html.span` is awkward, and a *closed, typed* API enforces a single type
//// scale + palette. No headless layer — text has no behavior beyond the element.
////
//// ## A size scale, not a heading scale
////
//// The numeric scale `s1…s7` is a **type-size ramp** (`s1` = largest), the way a
//// designer picks a step in Figma — it carries **no document semantics**. Every
//// step renders a neutral inline **`<span>`** by default (the common case in app
//// UIs, where semantic headings matter far less than on marketing pages). When
//// you *do* want a semantic element — a real `<h1>` on a public page, or a block
//// `<p>` — opt in with `render_as`:
////
//// ```gleam
//// text.s1([], [html.text("Big inline text")])            // <span>
//// text.s1([text.render_as(html.h1)], […])                // a real <h1>
//// text.s6([text.render_as(html.p)], […])                 // a block paragraph
//// ```
////
//// ## The API mirrors Lustre: `text.s1(attrs, children)`
////
//// Like every Lustre element, a helper takes a `List(Attr(msg))` then children;
//// the common case is an empty list. Each `Attr` is one typed, tokenized
//// decision:
////
//// ```gleam
//// text.s1([], [html.text("Heading")])                          // defaults
//// text.s1([text.color(text.Muted), text.align(text.Center)], […])
//// text.s1([text.id("intro"), text.on_click(Msg)], […])         // a11y / events
//// ```
////
//// `Attr` is **opaque** — every constructor is a tokenized modifier, a curated
//// a11y/event attr, or `render_as`. There is deliberately **no `class`/`style`
//// constructor**, so off-token / off-scale text can't be expressed (and no
//// tailwind-merge is needed). `color` defaults to `Foreground`; other modifiers
//// default to "normal" (omit the attr). Weight variants are baked members
//// (`S4M` = medium, `S4B` = bold) — a curated allow-list, not a free axis.
////
//// Emits `cn-*` names; the whole recipe (scale + color + modifiers) lives once
//// in the universal `styles/text.css` — shadcn doesn't vary the type recipe per
//// style, so neither do we (a style that restyles type adds a `.style-*`
//// overlay, the exception).

import gg_ui/helpers/cn
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

// --- the size scale ----------------------------------------------------------

/// The closed, **numeric size scale** — `s1…s7` (`s1` = largest), a type-size
/// ramp a designer picks a step from. It carries **no element semantics**; the
/// rendered element is always a neutral `<span>` unless `render_as` overrides it.
/// Each member bundles size + weight + leading + tracking + family as ONE
/// decision. **Weight variants are baked members** (`S4M` = medium, `S4B` =
/// bold) — a curated allow-list, NOT a free `weight` axis. Add a member only
/// when the design system defines it.
pub type Style {
  S1
  S2
  S3
  S4
  S4M
  S4B
  S5
  S5M
  S6
  S6M
  S6B
  S7
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

/// Render on a *different* element — a real Lustre element such as `html.h1`
/// (semantic heading) or `html.p` (block paragraph). Without it, the default is
/// a neutral inline `<span>` (the asChild / `useRender` analogue).
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

// --- named helpers — all default to a neutral inline `<span>` -----------------

pub fn s1(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(S1, attrs, children)
}

pub fn s2(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(S2, attrs, children)
}

pub fn s3(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(S3, attrs, children)
}

pub fn s4(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(S4, attrs, children)
}

pub fn s4_m(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(S4M, attrs, children)
}

pub fn s4_b(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(S4B, attrs, children)
}

pub fn s5(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(S5, attrs, children)
}

pub fn s5_m(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(S5M, attrs, children)
}

pub fn s6(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(S6, attrs, children)
}

pub fn s6_m(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(S6M, attrs, children)
}

pub fn s6_b(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(S6B, attrs, children)
}

pub fn s7(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  render(S7, attrs, children)
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
  attrs: List(Attr(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  let r = resolve(attrs)
  // Default element is a neutral inline span; `render_as` overrides it.
  let element = case r.render_as {
    Some(custom) -> custom
    None -> html.span
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
    S1 -> "cn-text-s1"
    S2 -> "cn-text-s2"
    S3 -> "cn-text-s3"
    S4 -> "cn-text-s4"
    S4M -> "cn-text-s4-m"
    S4B -> "cn-text-s4-b"
    S5 -> "cn-text-s5"
    S5M -> "cn-text-s5-m"
    S6 -> "cn-text-s6"
    S6M -> "cn-text-s6-m"
    S6B -> "cn-text-s6-b"
    S7 -> "cn-text-s7"
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

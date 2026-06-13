//// `Text` — typed, tokenized typography for app UIs. **A deliberate divergence
//// from shadcn**, which ships *no* Text component (you copy utility recipes).
//// gg_ui ships one because in Lustre hand-writing utility strings on `html.h1`
//// is awkward, and a *closed, typed* API enforces a single type scale + a fixed
//// set of presentational tokens: app text can't drift off-token or off-scale.
//// There is **no headless layer** — text has no behavior/ARIA beyond the
//// element you render it as (so, like `icon`, it lives only here).
////
//// ## Enforcement is in the type system, not convention
////
//// The helpers take `List(Attr(msg))` — an **opaque** type. Every constructor
//// is either a11y/structural (`id`/`aria`/`data`) or a **tokenized modifier**
//// (`color`/`align`/`transform`/`decoration`/`italic`/`truncate`/`whitespace`/
//// `word_break`/`wrap`/`opacity`/`selectable`). There is deliberately **no
//// `class`/`style` constructor**, so a raw, non-tokenized override *cannot
//// compile* on the helper path. Every modifier is a closed enum, so the whole
//// surface — the Latitude `Text` atom's prop set, but typed — stays on-scale.
////
//// `color` defaults to `Foreground` (omit it); other modifiers default to
//// "normal" (omit them). Going off-road is still possible, but only via the
//// explicit escape hatch `attributes(style, attrs)` — it returns the *open*
//// `Attribute` list, the one sanctioned place to merge raw `class`/`style` onto
//// a bare element. Off-road by opt-in, never by accident.
////
//// It emits `cn-*` names; the per-shape type scale (Style + Color) lives in
//// `styles/shapes/<style>/text.css`, the shape-invariant modifiers in
//// `styles/text.css`. **Element-agnostic**: named helpers (`text.h1`) default a
//// tag; for "H1 *look* on a semantic `<h3>`", merge `attributes(H1, …)` onto any
//// element — the asChild / `useRender` analogue.

import gg_ui/helpers/cn
import gleam/int
import gleam/list
import gva
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html

// --- axes --------------------------------------------------------------------

/// The closed, **numeric** type scale — `h1…h7`, the way a designer names text
/// styles in Figma ("set h5, it maps to the DS"). Each member bundles size +
/// weight + leading + tracking + family as ONE decision. **Weight variants are
/// baked enum members** (`H4M` = medium, `H4B` = bold), a curated allow-list —
/// NOT a free `weight` axis (which would permit off-scale combos). Add a member
/// only when the design system defines that style. Default element: `h1–h4` are
/// headings, `h5–h7` neutral (see the helpers).
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

/// Color — semantic tokens only, so text rides the Base Color / Theme axes.
/// `Foreground` is the default (omit `color`).
pub type Color {
  Foreground
  Muted
  Primary
  Destructive
}

/// Logical text alignment. `Start` is the default (omit `align`).
pub type Align {
  Start
  Center
  End
}

/// Letter-case transform. Omit for none.
pub type Transform {
  Uppercase
  Lowercase
  Capitalize
}

/// Text decoration. Omit for none.
pub type Decoration {
  Underline
  LineThrough
}

/// Truncation. `Ellipsis` = single line; `Lines(n)` = clamp to n lines
/// (clamped to 1–6, mirroring the Latitude atom).
pub type Truncate {
  Ellipsis
  Lines(Int)
}

/// `white-space`. Omit for `normal`.
pub type Whitespace {
  NoWrap
  Pre
  PreLine
  PreWrap
}

/// `word-break` / `overflow-wrap`. Omit for `normal`.
pub type WordBreak {
  BreakAll
  BreakWord
  KeepAll
}

/// `text-wrap` for balanced/pretty line breaking (headings, short blocks).
pub type Wrap {
  Balance
  Pretty
}

/// Text opacity steps. `O100` is the default (omit `opacity`).
pub type Opacity {
  O90
  O80
  O70
  O60
  O50
}

// --- the safe attribute vocabulary -------------------------------------------

/// A **safe** attribute for the `text.*` helpers. Opaque, so the only values
/// that exist are the ones the constructors below mint — structural
/// (`id`/`aria`/`data`) or a tokenized modifier. There is **no `class`/`style`
/// constructor**, which is what makes a non-tokenized override impossible to
/// express on the helper path.
pub opaque type Attr(msg) {
  AttrHtml(Attribute(msg))
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

// --- recipe ------------------------------------------------------------------

type Key {
  StyleKey(Style)
  ColorKey(Color)
  AlignKey(Align)
  TransformKey(Transform)
  DecorationKey(Decoration)
  ItalicKey
  TruncateKey(Truncate)
  WhitespaceKey(Whitespace)
  WordBreakKey(WordBreak)
  WrapKey(Wrap)
  OpacityKey(Opacity)
  SelectKey(Bool)
}

const base = "cn-text"

/// The styled attributes, **element-agnostic** — merge onto any element to
/// apply a text style without committing to its default tag (the asChild
/// analogue): `html.h2(text.attributes(H3, [text.color(text.Muted)]), [..])`.
///
/// Also the **escape hatch**: it returns the open `Attribute(msg)` list (the
/// resolved class + `data-slot` + any structural attrs), so this is the single
/// sanctioned place to knowingly prepend a raw `attribute.class`/`style`.
pub fn attributes(
  style style: Style,
  attrs attrs: List(Attr(msg)),
) -> List(Attribute(msg)) {
  let #(keys, html_attrs) = partition(attrs, [], [])
  [
    attribute.attribute("data-slot", "text"),
    attribute.class(classes(style, keys)),
    ..html_attrs
  ]
}

fn classes(style: Style, keys: List(Key)) -> String {
  gva.gva(default: base, resolver: resolve, defaults: [ColorKey(Foreground)])
  |> gva.with(StyleKey(style))
  |> gva.with_all(keys)
  |> gva.build
  |> fn(recipe) { cn.cn([recipe]) }
}

// Split the caller's attrs into gva modifier keys + passthrough HTML attributes.
fn partition(
  attrs: List(Attr(msg)),
  keys: List(Key),
  html_attrs: List(Attribute(msg)),
) -> #(List(Key), List(Attribute(msg))) {
  case attrs {
    [] -> #(list.reverse(keys), list.reverse(html_attrs))
    [attr, ..rest] ->
      case attr {
        AttrHtml(a) -> partition(rest, keys, [a, ..html_attrs])
        AttrColor(c) -> partition(rest, [ColorKey(c), ..keys], html_attrs)
        AttrAlign(a) -> partition(rest, [AlignKey(a), ..keys], html_attrs)
        AttrTransform(t) ->
          partition(rest, [TransformKey(t), ..keys], html_attrs)
        AttrDecoration(d) ->
          partition(rest, [DecorationKey(d), ..keys], html_attrs)
        AttrItalic -> partition(rest, [ItalicKey, ..keys], html_attrs)
        AttrTruncate(t) -> partition(rest, [TruncateKey(t), ..keys], html_attrs)
        AttrWhitespace(w) ->
          partition(rest, [WhitespaceKey(w), ..keys], html_attrs)
        AttrWordBreak(w) ->
          partition(rest, [WordBreakKey(w), ..keys], html_attrs)
        AttrWrap(w) -> partition(rest, [WrapKey(w), ..keys], html_attrs)
        AttrOpacity(o) -> partition(rest, [OpacityKey(o), ..keys], html_attrs)
        AttrSelectable(b) -> partition(rest, [SelectKey(b), ..keys], html_attrs)
      }
  }
}

fn resolve(key: Key) -> String {
  case key {
    StyleKey(style) -> style_class(style)
    ColorKey(color) -> color_class(color)
    AlignKey(align) -> align_class(align)
    TransformKey(transform) -> transform_class(transform)
    DecorationKey(decoration) -> decoration_class(decoration)
    ItalicKey -> "cn-text-italic"
    TruncateKey(truncate) -> truncate_class(truncate)
    WhitespaceKey(whitespace) -> whitespace_class(whitespace)
    WordBreakKey(word_break) -> word_break_class(word_break)
    WrapKey(wrap) -> wrap_class(wrap)
    OpacityKey(opacity) -> opacity_class(opacity)
    SelectKey(selectable) ->
      case selectable {
        True -> ""
        False -> "cn-text-select-none"
      }
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
    // Clamp to 1–6 lines; out-of-range values saturate (mirrors Latitude).
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

// --- named helpers — sugar over `attributes`, each with a default element ----
// `color` defaults to Foreground (add `text.color(…)` to override). Default
// element: h1–h4 are headings, h5–h7 are neutral `<p>` (a body-sized `<h6>`
// would pollute the a11y outline). Override the element via `attributes` on any
// tag. Weight variants are terse: `_m` = medium, `_b` = bold.

pub fn h1(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.h1, H1, attrs, children)
}

pub fn h2(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.h2, H2, attrs, children)
}

pub fn h3(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.h3, H3, attrs, children)
}

pub fn h4(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.h4, H4, attrs, children)
}

pub fn h4_m(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.h4, H4M, attrs, children)
}

pub fn h4_b(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.h4, H4B, attrs, children)
}

pub fn h5(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.p, H5, attrs, children)
}

pub fn h5_m(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.p, H5M, attrs, children)
}

pub fn h6(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.p, H6, attrs, children)
}

pub fn h6_m(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.p, H6M, attrs, children)
}

pub fn h6_b(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.p, H6B, attrs, children)
}

pub fn h7(
  attrs attrs: List(Attr(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(html.p, H7, attrs, children)
}

fn el(
  element: fn(List(Attribute(msg)), List(Element(msg))) -> Element(msg),
  style: Style,
  attrs: List(Attr(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  element(attributes(style:, attrs:), children)
}

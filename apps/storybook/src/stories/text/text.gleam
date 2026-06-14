//// Story mounts for the styled `Text` component (gg_ui/ui/text) — the typed,
//// tokenized typography primitive. The scale `s1…s7` is a SIZE ramp (no element
//// semantics); every step renders a neutral `<span>`, `render_as` opts into a
//// semantic element. The API mirrors Lustre: `text.s1(attrs, children)`.
//// `Playground` is the kitchen sink; `Scale` / `Colors` / `AsElement` render
//// fixed grids. Views call the styled layer ONLY — no raw Tailwind.

import gg_ui/ui/text
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

// --- Playground (kitchen sink) -------------------------------------------

pub fn mount_text_playground(
  selector: String,
  style: String,
  color: String,
  align: String,
  transform: String,
  decoration: String,
  italic: Bool,
  truncate: String,
  lines: Int,
  whitespace: String,
  word_break: String,
  wrap: String,
  opacity: String,
  selectable: Bool,
  content: String,
) -> Nil {
  // Each control contributes at most one typed `Attr`; "none"/default → omit.
  let attrs =
    [
      Some(text.color(parse_color(color))),
      option.map(parse_align(align), text.align),
      option.map(parse_transform(transform), text.transform),
      option.map(parse_decoration(decoration), text.decoration),
      case italic {
        True -> Some(text.italic())
        False -> None
      },
      option.map(parse_truncate(truncate, lines), text.truncate),
      option.map(parse_whitespace(whitespace), text.whitespace),
      option.map(parse_word_break(word_break), text.word_break),
      option.map(parse_wrap(wrap), text.wrap),
      option.map(parse_opacity(opacity), text.opacity),
      case selectable {
        True -> None
        False -> Some(text.selectable(False))
      },
    ]
    |> list.filter_map(option.to_result(_, Nil))

  let view = render_style(parse_style(style), attrs, [html.text(content)])
  let assert Ok(_) = lustre.start(lustre.element(center([view])), selector, Nil)
  Nil
}

// --- showcase views ------------------------------------------------------

/// The full closed scale, each member labeled — the numeric size specimen.
/// `s1` = largest; `_m`/`_b` are baked weight variants.
fn view_scale() -> Element(msg) {
  column([
    specimen("s1", text.s1([], [html.text("Size 1 — largest")])),
    specimen("s2", text.s2([], [html.text("Size 2")])),
    specimen("s3", text.s3([], [html.text("Size 3")])),
    specimen("s4", text.s4([], [html.text("Size 4")])),
    specimen("s4_m", text.s4_m([], [html.text("Size 4 — medium")])),
    specimen("s4_b", text.s4_b([], [html.text("Size 4 — bold")])),
    specimen("s5", text.s5([], [html.text("Size 5")])),
    specimen("s5_m", text.s5_m([], [html.text("Size 5 — medium")])),
    specimen(
      "s6",
      text.s6([], [
        html.text(
          "Size 6 is the default reading size, tuned for comfortable line length.",
        ),
      ]),
    ),
    specimen("s6_m", text.s6_m([], [html.text("Size 6 — medium")])),
    specimen("s6_b", text.s6_b([], [html.text("Size 6 — bold")])),
    specimen("s7", text.s7([], [html.text("Size 7 — smallest")])),
  ])
}

/// The orthogonal Color axis applied to one size.
fn view_colors() -> Element(msg) {
  column([
    specimen(
      "foreground",
      text.s5([], [
        html.text("Foreground — the default text color"),
      ]),
    ),
    specimen(
      "muted",
      text.s5([text.color(text.Muted)], [
        html.text("Muted — secondary / helper text"),
      ]),
    ),
    specimen(
      "primary",
      text.s5([text.color(text.Primary)], [
        html.text("Primary — accent emphasis"),
      ]),
    ),
    specimen(
      "destructive",
      text.s5([text.color(text.Destructive)], [
        html.text("Destructive — errors and danger"),
      ]),
    ),
  ])
}

/// The scale is size-only; the default element is a neutral `<span>`.
/// `render_as` opts into a semantic element when it matters.
fn view_as_element() -> Element(msg) {
  column([
    specimen(
      "s1 size, default <span> (inline)",
      text.s1([], [html.text("Inline by default")]),
    ),
    specimen(
      "s1 size, render_as <h1> (semantic heading)",
      text.s1([text.render_as(html.h1)], [
        html.text("A real <h1> for a public page"),
      ]),
    ),
    specimen(
      "s6 size, render_as <p> + id",
      text.s6([text.render_as(html.p), text.id("intro")], [
        html.text("A block paragraph, no className anywhere"),
      ]),
    ),
  ])
}

// --- mounts ---------------------------------------------------------------

pub fn mount_scale(selector: String) -> Nil {
  let assert Ok(_) = lustre.start(lustre.element(view_scale()), selector, Nil)
  Nil
}

pub fn mount_colors(selector: String) -> Nil {
  let assert Ok(_) = lustre.start(lustre.element(view_colors()), selector, Nil)
  Nil
}

pub fn mount_as_element(selector: String) -> Nil {
  let assert Ok(_) =
    lustre.start(lustre.element(view_as_element()), selector, Nil)
  Nil
}

// --- size dispatch --------------------------------------------------------

fn render_style(
  style: text.Style,
  attrs: List(text.Attr(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  case style {
    text.S1 -> text.s1(attrs, children)
    text.S2 -> text.s2(attrs, children)
    text.S3 -> text.s3(attrs, children)
    text.S4 -> text.s4(attrs, children)
    text.S4M -> text.s4_m(attrs, children)
    text.S4B -> text.s4_b(attrs, children)
    text.S5 -> text.s5(attrs, children)
    text.S5M -> text.s5_m(attrs, children)
    text.S6 -> text.s6(attrs, children)
    text.S6M -> text.s6_m(attrs, children)
    text.S6B -> text.s6_b(attrs, children)
    text.S7 -> text.s7(attrs, children)
  }
}

// --- arg parsing (safe fallbacks; "none"/unknown → omit the modifier) ------

fn parse_style(value: String) -> text.Style {
  case value {
    "s1" -> text.S1
    "s2" -> text.S2
    "s3" -> text.S3
    "s4" -> text.S4
    "s4_m" -> text.S4M
    "s4_b" -> text.S4B
    "s5" -> text.S5
    "s5_m" -> text.S5M
    "s6_m" -> text.S6M
    "s6_b" -> text.S6B
    "s7" -> text.S7
    _ -> text.S6
  }
}

fn parse_color(value: String) -> text.Color {
  case value {
    "muted" -> text.Muted
    "primary" -> text.Primary
    "destructive" -> text.Destructive
    _ -> text.Foreground
  }
}

fn parse_align(value: String) -> Option(text.Align) {
  case value {
    "center" -> Some(text.Center)
    "end" -> Some(text.End)
    "start" -> Some(text.Start)
    _ -> None
  }
}

fn parse_transform(value: String) -> Option(text.Transform) {
  case value {
    "uppercase" -> Some(text.Uppercase)
    "lowercase" -> Some(text.Lowercase)
    "capitalize" -> Some(text.Capitalize)
    _ -> None
  }
}

fn parse_decoration(value: String) -> Option(text.Decoration) {
  case value {
    "underline" -> Some(text.Underline)
    "line-through" -> Some(text.LineThrough)
    _ -> None
  }
}

fn parse_truncate(value: String, lines: Int) -> Option(text.Truncate) {
  case value {
    "ellipsis" -> Some(text.Ellipsis)
    "clamp" -> Some(text.Lines(lines))
    _ -> None
  }
}

fn parse_whitespace(value: String) -> Option(text.Whitespace) {
  case value {
    "nowrap" -> Some(text.NoWrap)
    "pre" -> Some(text.Pre)
    "pre-line" -> Some(text.PreLine)
    "pre-wrap" -> Some(text.PreWrap)
    _ -> None
  }
}

fn parse_word_break(value: String) -> Option(text.WordBreak) {
  case value {
    "break-all" -> Some(text.BreakAll)
    "break-word" -> Some(text.BreakWord)
    "keep-all" -> Some(text.KeepAll)
    _ -> None
  }
}

fn parse_wrap(value: String) -> Option(text.Wrap) {
  case value {
    "balance" -> Some(text.Balance)
    "pretty" -> Some(text.Pretty)
    _ -> None
  }
}

fn parse_opacity(value: String) -> Option(text.Opacity) {
  case value {
    "90" -> Some(text.O90)
    "80" -> Some(text.O80)
    "70" -> Some(text.O70)
    "60" -> Some(text.O60)
    "50" -> Some(text.O50)
    _ -> None
  }
}

// --- layout helpers -------------------------------------------------------

fn column(children: List(Element(msg))) -> Element(msg) {
  html.div(
    [attribute.class("mx-auto flex w-full max-w-2xl flex-col gap-8 text-left")],
    children,
  )
}

fn center(children: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("mx-auto w-full max-w-2xl")], children)
}

fn specimen(label: String, content: Element(msg)) -> Element(msg) {
  // Specimen label uses the smallest step, muted, block via render_as.
  html.div([attribute.class("flex flex-col gap-1")], [
    text.s7([text.color(text.Muted), text.render_as(html.p)], [
      html.text(label),
    ]),
    content,
  ])
}

//// Story mounts for the styled `Text` component (gg_ui/ui/text) — the typed,
//// tokenized typography primitive. Contrast with `Components/Typography`, the
//// shadcn-style docs-only recipe page; this is the gg_ui divergence: a real
//// component with a closed `Style` scale + tokenized modifiers and no className.
////
//// `Playground` is the kitchen sink — every tokenized axis as a Storybook
//// control, the Latitude `Text` prop set but typed. The showcase stories
//// (`Scale` / `Colors` / `AsElement`) render fixed grids. Views call the styled
//// layer ONLY (`import gg_ui/ui/text`) — no raw Tailwind, no `gg_base_ui`.

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

/// The full closed scale, each member labeled — the numeric "type styles"
/// specimen. h1–h4 are headings; h5–h7 neutral. `_m`/`_b` are weight variants.
fn view_scale() -> Element(msg) {
  column([
    specimen("h1", text.h1([], [html.text("Heading 1")])),
    specimen("h2", text.h2([], [html.text("Heading 2")])),
    specimen("h3", text.h3([], [html.text("Heading 3")])),
    specimen("h4", text.h4([], [html.text("Heading 4")])),
    specimen("h4_m", text.h4_m([], [html.text("Heading 4 — medium")])),
    specimen("h4_b", text.h4_b([], [html.text("Heading 4 — bold")])),
    specimen("h5", text.h5([], [html.text("Subtitle / large")])),
    specimen("h5_m", text.h5_m([], [html.text("Subtitle — medium")])),
    specimen(
      "h6",
      text.h6([], [
        html.text(
          "Body copy is the default reading size, tuned for comfortable line length and rhythm.",
        ),
      ]),
    ),
    specimen("h6_m", text.h6_m([], [html.text("Body — medium")])),
    specimen("h6_b", text.h6_b([], [html.text("Body — strong")])),
    specimen("h7", text.h7([], [html.text("Small / caption")])),
  ])
}

/// The orthogonal Color axis applied to one style.
fn view_colors() -> Element(msg) {
  column([
    specimen(
      "foreground",
      text.h5([], [html.text("Foreground — the default text color")]),
    ),
    specimen(
      "muted",
      text.h5([text.color(text.Muted)], [
        html.text("Muted — secondary / helper text"),
      ]),
    ),
    specimen(
      "primary",
      text.h5([text.color(text.Primary)], [
        html.text("Primary — accent emphasis"),
      ]),
    ),
    specimen(
      "destructive",
      text.h5([text.color(text.Destructive)], [
        html.text("Destructive — errors and danger"),
      ]),
    ),
  ])
}

/// Element-agnostic: apply a `Style` to a *different* tag via `attributes` —
/// the asChild analogue. Style and element are decoupled; still no className.
fn view_as_element() -> Element(msg) {
  column([
    specimen(
      "<h3> element + H1 style",
      html.h3(text.attributes(style: text.H1, attrs: []), [
        html.text("Looks like H1, semantically h3"),
      ]),
    ),
    specimen(
      "<h2> element + H3 style",
      html.h2(text.attributes(style: text.H3, attrs: [text.color(text.Muted)]), [
        html.text("Semantic h2, styled as h3, muted"),
      ]),
    ),
    // The curated `Attr` path: id/aria/data are typed; there is no
    // `text.class`, so a styling override can't be expressed here.
    specimen(
      "default helper + curated attrs (id)",
      text.h3([text.id("section-jokes")], [html.text("Same look, semantic h3")]),
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

// --- style dispatch (keeps the semantic element per style) ----------------

fn render_style(
  style: text.Style,
  attrs: List(text.Attr(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  case style {
    text.H1 -> text.h1(attrs, children)
    text.H2 -> text.h2(attrs, children)
    text.H3 -> text.h3(attrs, children)
    text.H4 -> text.h4(attrs, children)
    text.H4M -> text.h4_m(attrs, children)
    text.H4B -> text.h4_b(attrs, children)
    text.H5 -> text.h5(attrs, children)
    text.H5M -> text.h5_m(attrs, children)
    text.H6 -> text.h6(attrs, children)
    text.H6M -> text.h6_m(attrs, children)
    text.H6B -> text.h6_b(attrs, children)
    text.H7 -> text.h7(attrs, children)
  }
}

// --- arg parsing (safe fallbacks; "none"/unknown → omit the modifier) ------

fn parse_style(value: String) -> text.Style {
  case value {
    "h1" -> text.H1
    "h2" -> text.H2
    "h3" -> text.H3
    "h4" -> text.H4
    "h4_m" -> text.H4M
    "h4_b" -> text.H4B
    "h5" -> text.H5
    "h5_m" -> text.H5M
    "h6_m" -> text.H6M
    "h6_b" -> text.H6B
    "h7" -> text.H7
    _ -> text.H6
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
  html.div([attribute.class("flex flex-col gap-1")], [
    text.h7([text.color(text.Muted)], [html.text(label)]),
    content,
  ])
}

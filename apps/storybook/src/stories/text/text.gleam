//// Story mounts for the styled `Text` component (gg_ui/ui/text) — the typed,
//// tokenized typography primitive. `Playground` is the kitchen sink: every
//// tokenized `Props` key as a Storybook control. The showcase stories
//// (`Scale` / `Colors` / `AsElement`) render fixed grids. Views call the styled
//// layer ONLY (`import gg_ui/ui/text`) — no raw Tailwind, no `gg_base_ui`.

import gg_ui/ui/text.{Props}
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
  let props =
    Props(
      ..text.props(),
      color: parse_color(color),
      align: parse_align(align),
      transform: parse_transform(transform),
      decoration: parse_decoration(decoration),
      italic:,
      truncate: parse_truncate(truncate, lines),
      whitespace: parse_whitespace(whitespace),
      word_break: parse_word_break(word_break),
      wrap: parse_wrap(wrap),
      opacity: parse_opacity(opacity),
      selectable:,
    )
  let view = render_style(parse_style(style), props, [html.text(content)])
  let assert Ok(_) = lustre.start(lustre.element(center([view])), selector, Nil)
  Nil
}

// --- showcase views ------------------------------------------------------

/// The full closed scale, each member labeled — the numeric "type styles"
/// specimen. h1–h4 are headings; h5–h7 neutral. `_m`/`_b` are weight variants.
fn view_scale() -> Element(msg) {
  column([
    specimen("h1", text.h1(text.props(), [html.text("Heading 1")])),
    specimen("h2", text.h2(text.props(), [html.text("Heading 2")])),
    specimen("h3", text.h3(text.props(), [html.text("Heading 3")])),
    specimen("h4", text.h4(text.props(), [html.text("Heading 4")])),
    specimen("h4_m", text.h4_m(text.props(), [html.text("Heading 4 — medium")])),
    specimen("h4_b", text.h4_b(text.props(), [html.text("Heading 4 — bold")])),
    specimen("h5", text.h5(text.props(), [html.text("Subtitle / large")])),
    specimen("h5_m", text.h5_m(text.props(), [html.text("Subtitle — medium")])),
    specimen(
      "h6",
      text.h6(text.props(), [
        html.text(
          "Body copy is the default reading size, tuned for comfortable line length and rhythm.",
        ),
      ]),
    ),
    specimen("h6_m", text.h6_m(text.props(), [html.text("Body — medium")])),
    specimen("h6_b", text.h6_b(text.props(), [html.text("Body — strong")])),
    specimen("h7", text.h7(text.props(), [html.text("Small / caption")])),
  ])
}

/// The orthogonal Color axis applied to one style.
fn view_colors() -> Element(msg) {
  column([
    specimen(
      "foreground",
      text.h5(text.props(), [
        html.text("Foreground — the default text color"),
      ]),
    ),
    specimen(
      "muted",
      text.h5(Props(..text.props(), color: text.Muted), [
        html.text("Muted — secondary / helper text"),
      ]),
    ),
    specimen(
      "primary",
      text.h5(Props(..text.props(), color: text.Primary), [
        html.text("Primary — accent emphasis"),
      ]),
    ),
    specimen(
      "destructive",
      text.h5(Props(..text.props(), color: text.Destructive), [
        html.text("Destructive — errors and danger"),
      ]),
    ),
  ])
}

/// `render_as` puts a `Style` on a *different* element — the asChild analogue.
/// Style and document structure are decoupled; still no className.
fn view_as_element() -> Element(msg) {
  column([
    specimen(
      "h1 style, render_as <h3>",
      text.h1(Props(..text.props(), render_as: Some(html.h3)), [
        html.text("Looks like H1, semantically h3"),
      ]),
    ),
    specimen(
      "h3 style + curated attrs (id)",
      text.h3(Props(..text.props(), html_attrs: [text.id("section-jokes")]), [
        html.text("Semantic h3 with an id, no className anywhere"),
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

// --- style dispatch (keeps the semantic element per style) ----------------

fn render_style(
  style: text.Style,
  props: text.Props(msg),
  children: List(Element(msg)),
) -> Element(msg) {
  case style {
    text.H1 -> text.h1(props, children)
    text.H2 -> text.h2(props, children)
    text.H3 -> text.h3(props, children)
    text.H4 -> text.h4(props, children)
    text.H4M -> text.h4_m(props, children)
    text.H4B -> text.h4_b(props, children)
    text.H5 -> text.h5(props, children)
    text.H5M -> text.h5_m(props, children)
    text.H6 -> text.h6(props, children)
    text.H6M -> text.h6_m(props, children)
    text.H6B -> text.h6_b(props, children)
    text.H7 -> text.h7(props, children)
  }
}

// --- arg parsing (safe fallbacks; "none"/unknown → default/omit) -----------

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

fn parse_align(value: String) -> text.Align {
  case value {
    "center" -> text.Center
    "end" -> text.End
    _ -> text.Start
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
    text.h7(Props(..text.props(), color: text.Muted), [html.text(label)]),
    content,
  ])
}

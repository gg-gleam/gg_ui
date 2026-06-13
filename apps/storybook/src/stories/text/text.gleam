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

/// The full closed scale, each member labeled — the "type styles" specimen.
fn view_scale() -> Element(msg) {
  column([
    specimen("display", text.display([], [html.text("Display")])),
    specimen("h1", text.h1([], [html.text("Heading 1")])),
    specimen("h2", text.h2([], [html.text("Heading 2")])),
    specimen("h3", text.h3([], [html.text("Heading 3")])),
    specimen("h4", text.h4([], [html.text("Heading 4")])),
    specimen(
      "lead",
      text.lead([text.color(text.Muted)], [
        html.text(
          "A lead paragraph that introduces a section with a softer, larger voice.",
        ),
      ]),
    ),
    specimen("large", text.large([], [html.text("Are you absolutely sure?")])),
    specimen(
      "body",
      text.body([], [
        html.text(
          "Body copy is the default reading size, tuned for comfortable line length and rhythm.",
        ),
      ]),
    ),
    specimen(
      "body-strong",
      text.body_strong([], [
        html.text(
          "Body strong is the same size with a heavier weight for emphasis.",
        ),
      ]),
    ),
    specimen("small", text.small([], [html.text("Email address")])),
    specimen(
      "caption",
      text.caption([text.color(text.Muted)], [
        html.text("Enter the email you signed up with."),
      ]),
    ),
  ])
}

/// The orthogonal Color axis applied to one style.
fn view_colors() -> Element(msg) {
  column([
    specimen(
      "foreground",
      text.large([], [html.text("Foreground — the default text color")]),
    ),
    specimen(
      "muted",
      text.large([text.color(text.Muted)], [
        html.text("Muted — secondary / helper text"),
      ]),
    ),
    specimen(
      "primary",
      text.large([text.color(text.Primary)], [
        html.text("Primary — accent emphasis"),
      ]),
    ),
    specimen(
      "destructive",
      text.large([text.color(text.Destructive)], [
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
    text.Display -> text.display(attrs, children)
    text.H1 -> text.h1(attrs, children)
    text.H2 -> text.h2(attrs, children)
    text.H3 -> text.h3(attrs, children)
    text.H4 -> text.h4(attrs, children)
    text.Lead -> text.lead(attrs, children)
    text.Large -> text.large(attrs, children)
    text.Body -> text.body(attrs, children)
    text.BodyStrong -> text.body_strong(attrs, children)
    text.Small -> text.small(attrs, children)
    text.Caption -> text.caption(attrs, children)
  }
}

// --- arg parsing (safe fallbacks; "none"/unknown → omit the modifier) ------

fn parse_style(value: String) -> text.Style {
  case value {
    "display" -> text.Display
    "h1" -> text.H1
    "h2" -> text.H2
    "h3" -> text.H3
    "h4" -> text.H4
    "lead" -> text.Lead
    "large" -> text.Large
    "body-strong" -> text.BodyStrong
    "small" -> text.Small
    "caption" -> text.Caption
    _ -> text.Body
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
    text.caption([text.color(text.Muted)], [html.text(label)]),
    content,
  ])
}

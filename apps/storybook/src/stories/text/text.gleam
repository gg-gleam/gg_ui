//// Story mounts for the styled `Text` component (gg_ui/ui/text) — the typed,
//// tokenized typography primitive. Contrast with `Components/Typography`, which
//// is the shadcn-style docs-only recipe page; this is the gg_ui divergence: a
//// real component with a closed `Style` scale + `Color` axis and no className.
////
//// Note these views call the styled layer ONLY (`import gg_ui/ui/text`) — no raw
//// Tailwind, no `gg_base_ui`. Color is always one of the typed tokens.

import gg_ui/ui/text
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

// --- views ---------------------------------------------------------------

/// The full closed scale, each member labeled — the "type styles" specimen.
fn view_scale() -> Element(msg) {
  column([
    specimen(
      "display",
      text.display(color: text.Foreground, attrs: [], children: [
        html.text("Display"),
      ]),
    ),
    specimen(
      "h1",
      text.h1(color: text.Foreground, attrs: [], children: [
        html.text("Heading 1"),
      ]),
    ),
    specimen(
      "h2",
      text.h2(color: text.Foreground, attrs: [], children: [
        html.text("Heading 2"),
      ]),
    ),
    specimen(
      "h3",
      text.h3(color: text.Foreground, attrs: [], children: [
        html.text("Heading 3"),
      ]),
    ),
    specimen(
      "h4",
      text.h4(color: text.Foreground, attrs: [], children: [
        html.text("Heading 4"),
      ]),
    ),
    specimen(
      "lead",
      text.lead(color: text.Muted, attrs: [], children: [
        html.text(
          "A lead paragraph that introduces a section with a softer, larger voice.",
        ),
      ]),
    ),
    specimen(
      "large",
      text.large(color: text.Foreground, attrs: [], children: [
        html.text("Are you absolutely sure?"),
      ]),
    ),
    specimen(
      "body",
      text.body(color: text.Foreground, attrs: [], children: [
        html.text(
          "Body copy is the default reading size, tuned for comfortable line length and rhythm.",
        ),
      ]),
    ),
    specimen(
      "body-strong",
      text.body_strong(color: text.Foreground, attrs: [], children: [
        html.text(
          "Body strong is the same size with a heavier weight for emphasis.",
        ),
      ]),
    ),
    specimen(
      "small",
      text.small(color: text.Foreground, attrs: [], children: [
        html.text("Email address"),
      ]),
    ),
    specimen(
      "caption",
      text.caption(color: text.Muted, attrs: [], children: [
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
      text.large(color: text.Foreground, attrs: [], children: [
        html.text("Foreground — the default text color"),
      ]),
    ),
    specimen(
      "muted",
      text.large(color: text.Muted, attrs: [], children: [
        html.text("Muted — secondary / helper text"),
      ]),
    ),
    specimen(
      "primary",
      text.large(color: text.Primary, attrs: [], children: [
        html.text("Primary — accent emphasis"),
      ]),
    ),
    specimen(
      "destructive",
      text.large(color: text.Destructive, attrs: [], children: [
        html.text("Destructive — errors and danger"),
      ]),
    ),
  ])
}

/// Element-agnostic: the H3 *look* on a semantic `<h2>` via `attributes` — the
/// asChild analogue. Style and element are decoupled; still no className.
fn view_as_element() -> Element(msg) {
  column([
    specimen(
      "<h2> element + H3 style",
      html.h2(text.attributes(style: text.H3, color: text.Foreground), [
        html.text("Semantic h2, styled as h3"),
      ]),
    ),
    specimen(
      "default: text.h3 → <h3> element",
      text.h3(color: text.Foreground, attrs: [], children: [
        html.text("Same look, semantic h3"),
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

// --- layout helpers -------------------------------------------------------

fn column(children: List(Element(msg))) -> Element(msg) {
  html.div(
    [attribute.class("mx-auto flex w-full max-w-2xl flex-col gap-8 text-left")],
    children,
  )
}

fn specimen(label: String, content: Element(msg)) -> Element(msg) {
  html.div([attribute.class("flex flex-col gap-1")], [
    html.div(
      [
        attribute.class(
          "text-xs font-medium tracking-wide text-muted-foreground uppercase",
        ),
      ],
      [html.text(label)],
    ),
    content,
  ])
}

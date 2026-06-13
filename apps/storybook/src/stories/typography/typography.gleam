//// Story mounts for **Typography**. Following shadcn, gg_ui ships *no*
//// typography component — typography is a catalogue of utility-class recipes on
//// native elements, demonstrated here (the gg_ui analogue of shadcn's docs
//// page), not a styled-kit surface. So these views use raw Tailwind utilities
//// directly (legitimate in a story — stories live in the consumer app, which
//// imports Tailwind), exactly mirroring shadcn's JSX examples. The recipes:
////   - color is always a token (`text-muted-foreground`, `text-primary`) so it
////     rides the Base Color / Theme axes;
////   - headings opt into the FONT axis via `font-heading` (flip the Font
////     toolbar: editorial → serif headings, mono → monospace);
////   - vertical rhythm is owned by the *following* element's top margin, guarded
////     (`[&:not(:first-child)]:mt-6`, `first:mt-0`).
//// See dev-docs/typography.md.

import gleam/list
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

// --- recipes -------------------------------------------------------------
// Each helper is one shadcn typography recipe. The class string IS the recipe.

fn h1(text: String) -> Element(msg) {
  html.h1(
    [
      attribute.class(
        "font-heading scroll-m-20 text-4xl font-extrabold tracking-tight "
        <> "text-balance",
      ),
    ],
    [html.text(text)],
  )
}

fn h2(text: String) -> Element(msg) {
  html.h2(
    [
      attribute.class(
        "font-heading mt-10 scroll-m-20 border-b pb-2 text-3xl font-semibold "
        <> "tracking-tight first:mt-0",
      ),
    ],
    [html.text(text)],
  )
}

fn h3(text: String) -> Element(msg) {
  html.h3(
    [
      attribute.class(
        "font-heading mt-8 scroll-m-20 text-2xl font-semibold tracking-tight",
      ),
    ],
    [html.text(text)],
  )
}

fn h4(text: String) -> Element(msg) {
  html.h4(
    [
      attribute.class(
        "font-heading scroll-m-20 text-xl font-semibold tracking-tight",
      ),
    ],
    [html.text(text)],
  )
}

fn p(children: List(Element(msg))) -> Element(msg) {
  html.p([attribute.class("leading-7 [&:not(:first-child)]:mt-6")], children)
}

fn lead(text: String) -> Element(msg) {
  html.p([attribute.class("text-xl text-muted-foreground")], [html.text(text)])
}

fn large(text: String) -> Element(msg) {
  html.div([attribute.class("text-lg font-semibold")], [html.text(text)])
}

fn small(text: String) -> Element(msg) {
  html.small([attribute.class("text-sm leading-none font-medium")], [
    html.text(text),
  ])
}

fn muted(text: String) -> Element(msg) {
  html.p([attribute.class("text-sm text-muted-foreground")], [html.text(text)])
}

fn blockquote(text: String) -> Element(msg) {
  html.blockquote([attribute.class("mt-6 border-l-2 pl-6 italic")], [
    html.text(text),
  ])
}

fn inline_code(text: String) -> Element(msg) {
  html.code(
    [
      attribute.class(
        "relative rounded bg-muted px-[0.3rem] py-[0.2rem] font-mono text-sm "
        <> "font-semibold",
      ),
    ],
    [html.text(text)],
  )
}

fn link(href: String, text: String) -> Element(msg) {
  html.a(
    [
      attribute.href(href),
      attribute.class("font-medium text-primary underline underline-offset-4"),
    ],
    [html.text(text)],
  )
}

fn ul(items: List(String)) -> Element(msg) {
  html.ul(
    [attribute.class("my-6 ml-6 list-disc [&>li]:mt-2")],
    list_items(items),
  )
}

fn list_items(items: List(String)) -> List(Element(msg)) {
  items
  |> list.map(fn(item) { html.li([], [html.text(item)]) })
}

fn table(headers: List(String), rows: List(List(String))) -> Element(msg) {
  let th = fn(text) {
    html.th([attribute.class("border px-4 py-2 text-left font-bold")], [
      html.text(text),
    ])
  }
  let td = fn(text) {
    html.td([attribute.class("border px-4 py-2 text-left")], [html.text(text)])
  }
  let tr = fn(cells) {
    html.tr([attribute.class("m-0 border-t p-0 even:bg-muted")], cells)
  }
  html.div([attribute.class("my-6 w-full overflow-y-auto")], [
    html.table([attribute.class("w-full")], [
      html.thead([], [tr(list.map(headers, th))]),
      html.tbody([], list.map(rows, fn(cells) { tr(list.map(cells, td)) })),
    ]),
  ])
}

// --- views ---------------------------------------------------------------

/// The full article — every recipe in context, the canonical specimen.
fn view_overview() -> Element(msg) {
  column([
    h1("Taxing Laughter: The Joke Tax Chronicles"),
    lead(
      "Once upon a time, in a far-off land, there was a very lazy king who "
      <> "spent all day lounging on his throne.",
    ),
    h2("The King's Plan"),
    p([
      html.text("The king thought long and hard, and finally came up with "),
      link("#", "a brilliant plan"),
      html.text(": he would tax the jokes in the kingdom."),
    ]),
    blockquote(
      "\"After all,\" he said, \"everyone enjoys a good joke, so it's only fair "
      <> "that they should pay for the privilege.\"",
    ),
    h3("The Joke Tax"),
    p([
      html.text(
        "The king's subjects were not amused. They grumbled and complained:",
      ),
    ]),
    ul([
      "1st level of puns: 5 gold coins",
      "2nd level of jokes: 10 gold coins",
      "3rd level of one-liners: 20 gold coins",
    ]),
    p([
      html.text("People stopped telling jokes, and the kingdom fell into a "),
      html.text("gloom — until a court jester named Jokester refused to let "),
      html.text("the king's foolishness get him down."),
    ]),
    table(["King's Treasury", "People's happiness"], [
      ["Empty", "Overflowing"],
      ["Modest", "Satisfied"],
      ["Full", "Ecstatic"],
    ]),
    p([
      html.text("The king repealed the joke tax, and the kingdom lived "),
      html.text("happily ever after."),
    ]),
  ])
}

/// Each block-level element, labeled, for isolated review.
fn view_elements() -> Element(msg) {
  column([
    specimen("h1", h1("The Joke Tax Chronicles")),
    specimen("h2", h2("The King's Plan")),
    specimen("h3", h3("The Joke Tax")),
    specimen("h4", h4("People stopped telling jokes")),
    specimen(
      "p",
      p([
        html.text(
          "The king, seeing how much happier his subjects were, realized the "
          <> "error of his ways and repealed the joke tax.",
        ),
      ]),
    ),
    specimen(
      "blockquote",
      blockquote("\"After all,\" he said, \"everyone enjoys a good joke.\""),
    ),
    specimen("list", ul(["First level of puns", "Second level of jokes"])),
    specimen(
      "inline code",
      p([
        html.text("Install with "),
        inline_code("gleam add gg_ui"),
        html.text("."),
      ]),
    ),
    specimen(
      "table",
      table(["Treasury", "Happiness"], [["Empty", "Overflowing"]]),
    ),
  ])
}

/// The semantic text roles — the shared scale component internals draw from
/// (DialogTitle ≈ Large, DialogDescription ≈ Muted, FieldLabel ≈ Small).
fn view_roles() -> Element(msg) {
  column([
    specimen(
      "Lead",
      lead("A modal dialog that interrupts the user with important content."),
    ),
    specimen("Large", large("Are you absolutely sure?")),
    specimen("Small", small("Email address")),
    specimen("Muted", muted("Enter your email address.")),
  ])
}

// --- mounts --------------------------------------------------------------

pub fn mount_overview(selector: String) -> Nil {
  let assert Ok(_) =
    lustre.start(lustre.element(view_overview()), selector, Nil)
  Nil
}

pub fn mount_elements(selector: String) -> Nil {
  let assert Ok(_) =
    lustre.start(lustre.element(view_elements()), selector, Nil)
  Nil
}

pub fn mount_roles(selector: String) -> Nil {
  let assert Ok(_) = lustre.start(lustre.element(view_roles()), selector, Nil)
  Nil
}

// --- layout helpers ------------------------------------------------------

/// A readable, left-aligned column (the canvas is otherwise centered).
fn column(children: List(Element(msg))) -> Element(msg) {
  html.div(
    [attribute.class("mx-auto w-full max-w-2xl text-left text-foreground")],
    children,
  )
}

/// A labeled specimen: a muted caption above the rendered recipe.
fn specimen(label: String, content: Element(msg)) -> Element(msg) {
  html.div([attribute.class("mb-8")], [
    html.div(
      [
        attribute.class(
          "mb-1 text-xs font-medium tracking-wide text-muted-foreground "
          <> "uppercase",
        ),
      ],
      [html.text(label)],
    ),
    content,
  ])
}

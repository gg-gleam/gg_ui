//// Story mounts for the styled `input`. Static views (`lustre.element`) — the
//// input is a bare styled native element with no Gleam-side state. Dogfoods
//// `text` for the field labels (rule 6).

import gg_ui/ui/input
import gg_ui/ui/text
import gleam/list
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

fn mount(view: Element(Nil), selector: String) -> Nil {
  let assert Ok(_) = lustre.start(lustre.element(view), selector, Nil)
  Nil
}

pub fn mount_input_playground(
  selector: String,
  input_type: String,
  placeholder: String,
  disabled: Bool,
  invalid: Bool,
) -> Nil {
  let base = [
    attribute.type_(input_type),
    attribute.placeholder(placeholder),
    attribute.attribute("aria-label", "Playground input"),
    attribute.disabled(disabled),
  ]
  let attrs = case invalid {
    True -> [attribute.attribute("aria-invalid", "true"), ..base]
    False -> base
  }
  mount(html.div([attribute.class("w-64")], [input.input(attrs)]), selector)
}

// A labelled field: a `<label for>` ↔ input `id` association (proper a11y); the
// label text dogfoods `text` for the typography (rule 6).
fn field(
  id: String,
  label: String,
  attrs: List(attribute.Attribute(Nil)),
) -> Element(Nil) {
  html.div([attribute.class("flex flex-col gap-1.5")], [
    html.label([attribute.for(id)], [
      text.s6([text.color(text.Muted)], [html.text(label)]),
    ]),
    input.input([attribute.id(id), ..attrs]),
  ])
}

pub fn mount_input_types(selector: String) -> Nil {
  let fields = [
    #("Text", "text", "Type here"),
    #("Email", "email", "name@example.com"),
    #("Password", "password", "••••••••"),
    #("Number", "number", "0"),
    #("Time", "time", ""),
    #("Date", "date", ""),
  ]
  let rows =
    list.map(fields, fn(f) {
      let #(label, kind, placeholder) = f
      field("input-type-" <> kind, label, [
        attribute.type_(kind),
        attribute.placeholder(placeholder),
      ])
    })
  mount(html.div([attribute.class("flex w-64 flex-col gap-4")], rows), selector)
}

pub fn mount_input_states(selector: String) -> Nil {
  mount(
    html.div([attribute.class("flex w-64 flex-col gap-4")], [
      field("input-default", "Default", [attribute.placeholder("Default")]),
      field("input-invalid", "Invalid", [
        attribute.value("Invalid value"),
        attribute.attribute("aria-invalid", "true"),
      ]),
      field("input-disabled", "Disabled", [
        attribute.value("Disabled"),
        attribute.disabled(True),
      ]),
    ]),
    selector,
  )
}

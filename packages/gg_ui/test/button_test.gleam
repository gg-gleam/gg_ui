import birdie
import gg_ui/ui/button
import gleam/string
import gleeunit/should
import lustre/attribute
import lustre/element
import lustre/element/html

// A caller's `class` (passed in attrs) must win over a conflicting structural
// default via tailwind-merge: `justify-between` removes the component's
// `justify-center`, while non-conflicting raw classes (`w-full`) and the cn-*
// recipe survive.
pub fn class_override_resolves_conflict_test() {
  let markup =
    button.button(
      button.Default,
      button.Medium,
      [attribute.class("justify-between w-full")],
      [html.text("Click me")],
    )
    |> element.to_readable_string

  string.contains(markup, "justify-between") |> should.be_true
  string.contains(markup, "w-full") |> should.be_true
  string.contains(markup, "cn-button") |> should.be_true
  // the default was dropped, not merely appended
  string.contains(markup, "justify-center") |> should.be_false
}

pub fn classes_default_medium_test() {
  button.classes(variant: button.Default, size: button.Medium)
  |> birdie.snap(title: "gg_ui button classes — default / medium")
}

pub fn classes_outline_sm_test() {
  button.classes(variant: button.Outline, size: button.Sm)
  |> birdie.snap(title: "gg_ui button classes — outline / sm")
}

pub fn classes_ghost_icon_test() {
  button.classes(variant: button.Ghost, size: button.Icon)
  |> birdie.snap(title: "gg_ui button classes — ghost / icon")
}

pub fn render_default_test() {
  button.button(button.Default, button.Medium, [], [html.text("Click me")])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui button render — default")
}

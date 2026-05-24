import birdie
import gg_ui/ui/button
import lustre/element
import lustre/element/html

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

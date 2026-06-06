import birdie
import gg_base_ui/button/button as base_button
import lustre/element
import lustre/element/html

pub fn default_render_test() {
  base_button.button(config: base_button.config(), attrs: [], children: [
    html.text("Click me"),
  ])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_base_ui headless button — default render")
}

// Disabled, not focusable-when-disabled → native `disabled` attribute.
pub fn disabled_render_test() {
  base_button.button(
    config: base_button.Config(disabled: True, focusable_when_disabled: False),
    attrs: [],
    children: [html.text("Disabled")],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_base_ui headless button — disabled")
}

// Disabled but focusable → keeps `aria-disabled` instead of `disabled`, so it
// stays in the tab order. This is the subtle Base UI behavior worth pinning.
pub fn disabled_focusable_render_test() {
  base_button.button(
    config: base_button.Config(disabled: True, focusable_when_disabled: True),
    attrs: [],
    children: [html.text("Disabled but focusable")],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_base_ui headless button — disabled, focusable")
}

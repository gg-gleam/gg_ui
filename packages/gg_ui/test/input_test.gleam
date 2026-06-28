//// Render contract for the styled `input` — the `cn-input` recipe + `data-slot`
//// on a native `<input>`, with native attributes passing through `attrs`.

import birdie
import gg_ui/ui/input
import lustre/attribute
import lustre/element

pub fn input_basic_test() {
  input.input([attribute.placeholder("Email"), attribute.type_("email")])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui input — basic (email + placeholder)")
}

pub fn input_invalid_test() {
  // aria-invalid drives the destructive ring via the recipe (no separate flag).
  input.input([
    attribute.value("nope"),
    attribute.attribute("aria-invalid", "true"),
  ])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui input — aria-invalid")
}

pub fn input_disabled_time_test() {
  // `type` is just a passthrough attribute — this is the time field.
  input.input([attribute.type_("time"), attribute.disabled(True)])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui input — disabled time field")
}

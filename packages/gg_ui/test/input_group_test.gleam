import birdie
import gg_ui/ui/input_group
import lustre/attribute
import lustre/element
import lustre/element/html

// --- render contracts ----------------------------------------------------

pub fn render_leading_icon_test() {
  input_group.input_group([], [
    input_group.input([attribute.placeholder("Search…")]),
    input_group.addon(input_group.InlineStart, [], [html.text("⌕")]),
  ])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui input_group render — leading addon + input")
}

pub fn render_trailing_button_test() {
  input_group.input_group([], [
    input_group.input([]),
    input_group.addon(input_group.InlineEnd, [], [
      input_group.button(
        input_group.IconXs,
        [attribute.attribute("aria-label", "Open")],
        [
          html.text("▾"),
        ],
      ),
    ]),
  ])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui input_group render — trailing icon button")
}

// --- addon align contract ------------------------------------------------
// Each align must emit its own `cn-*` class *and* the structural `data-align`
// marker the container keys layout off — both come from one `addon` call.

pub fn addon_align_inline_start_test() {
  input_group.addon(input_group.InlineStart, [], [html.text("x")])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui input_group addon — inline-start")
}

pub fn addon_align_inline_end_test() {
  input_group.addon(input_group.InlineEnd, [], [html.text("x")])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui input_group addon — inline-end")
}

pub fn addon_align_block_start_test() {
  input_group.addon(input_group.BlockStart, [], [html.text("x")])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui input_group addon — block-start")
}

pub fn addon_align_block_end_test() {
  input_group.addon(input_group.BlockEnd, [], [html.text("x")])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui input_group addon — block-end")
}

// --- error state wiring --------------------------------------------------
// shadcn's error styling is container-level (`has-[[data-slot][aria-invalid=
// true]]:…`). The markup contract that triggers it: the control carries both
// `data-slot="input-group-control"` and the caller's `aria-invalid="true"`.

pub fn render_invalid_input_test() {
  input_group.input_group([], [
    input_group.input([attribute.attribute("aria-invalid", "true")]),
  ])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui input_group render — invalid input wiring")
}

pub fn text_addon_test() {
  input_group.text([], [html.text("USD")])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui input_group text addon")
}

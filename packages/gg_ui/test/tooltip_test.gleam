import birdie
import gg_ui/positioning
import gg_ui/ui/button
import gg_ui/ui/tooltip
import gleam/option.{Some}
import lustre/attribute
import lustre/element
import lustre/element/html

// A deterministic handle so the rendered id / `anchor-name` / `interestfor` are
// stable across runs (a generated base id would churn the snapshot every time).
fn handle() -> tooltip.Anatomy {
  tooltip.anatomy_with_id("demo")
}

// --- trigger: interest invoker wiring + delays ---------------------------
//
// The styled `trigger` merges the headless behaviour (`interestfor` +
// `anchor-name` + native `interest-delay-*` + `aria-describedby`) onto a styled
// `Button`. Pins that the Interest Invoker wiring and the delays land on the
// element, and that button props are honored.

pub fn trigger_outline_medium_test() {
  tooltip.trigger(
    handle(),
    variant: button.Outline,
    size: button.Medium,
    delay: tooltip.default_delay,
    close_delay: tooltip.default_close_delay,
    attrs: [],
    children: [html.text("Hover")],
  )
  |> element.to_readable_string
  |> birdie.snap(
    title: "gg_ui tooltip trigger — outline / medium, default delay (0/0)",
  )
}

pub fn trigger_custom_delay_test() {
  tooltip.trigger(
    handle(),
    variant: button.Ghost,
    size: button.IconSm,
    delay: 0,
    close_delay: 150,
    attrs: [],
    children: [html.text("?")],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui tooltip trigger — ghost / icon-sm, 0/150 delay")
}

// The `attrs` passthrough (Base UI's `render`-prop ergonomics): caller
// attributes/events land on the styled button alongside the trigger's wiring.
// Here a native `onclick` and a `data-*` flow through; the behavior attributes
// (anchor id, `interestfor`, `aria-describedby`, anchor-name `style`) are still
// emitted, applied last so they win any conflict.
pub fn trigger_attrs_passthrough_test() {
  tooltip.trigger(
    handle(),
    variant: button.Outline,
    size: button.Medium,
    delay: tooltip.default_delay,
    close_delay: tooltip.default_close_delay,
    attrs: [
      attribute.attribute("onclick", "window.alert('hi')"),
      attribute.attribute("data-action", "save"),
    ],
    children: [html.text("Hover")],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui tooltip trigger — attrs passthrough (onclick)")
}

// --- content: hint markup + side offset ----------------------------------
//
// `content` is the positioned `popover="hint"` box with `role="tooltip"`. The
// arrow toggles a wider side offset (10 vs 4) and the decorative caret.

pub fn content_no_arrow_test() {
  tooltip.content(
    handle(),
    side: positioning.Top,
    align: positioning.Center,
    arrow: False,
    children: [html.text("Add to library")],
  )
  |> element.to_readable_string
  |> birdie.snap(
    title: "gg_ui tooltip content — top/center, no arrow (offset 4)",
  )
}

pub fn content_with_arrow_test() {
  tooltip.content(
    handle(),
    side: positioning.Bottom,
    align: positioning.Center,
    arrow: True,
    children: [html.text("Add to library")],
  )
  |> element.to_readable_string
  |> birdie.snap(
    title: "gg_ui tooltip content — bottom/center, with arrow (offset 10)",
  )
}

// --- terse: Options defaults + record-update spread ----------------------
//
// `tooltip.options()` resolves all defaults (top/center, no arrow, 0/0 delay —
// shadcn's snappy reveal); record-update overrides only what's passed — here a
// deterministic id.

pub fn terse_defaults_test() {
  tooltip.tooltip(
    label: [html.text("Hover")],
    options: tooltip.Options(..tooltip.options(), id: Some("demo")),
    content: [html.text("Add to library")],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui tooltip terse — defaults (top/center, 0/0)")
}

// `tooltip_with_trigger` takes a caller-supplied trigger element (here a plain
// `<button>` carrying `trigger_attributes`); the `text`/`variant`/`size` in
// `options` don't apply, while placement/arrow/delay/id still do.
pub fn terse_custom_trigger_test() {
  tooltip.tooltip_with_trigger(
    trigger: fn(tip) {
      html.button(tooltip.trigger_attributes(tip, delay: 600, close_delay: 0), [
        html.text("Custom"),
      ])
    },
    options: tooltip.Options(..tooltip.options(), id: Some("demo")),
    content: [html.text("Add to library")],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui tooltip terse — custom trigger callback")
}

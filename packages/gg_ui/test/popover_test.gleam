import birdie
import gg_ui/positioning
import gg_ui/ui/button
import gg_ui/ui/popover
import gleam/option.{None, Some}
import lustre/element
import lustre/element/html

// A deterministic handle so the rendered id / `anchor-name` are stable across
// runs (a generated base id would churn the snapshot every time).
fn handle() -> popover.Anatomy {
  popover.anatomy_with_id("demo")
}

// --- trigger: button props are honored -----------------------------------
//
// The styled `trigger` forwards the `variant` / `size` it's handed to the
// underlying `Button`. These pin that the props are honored: the same headless
// trigger behaviour (`command` / `commandfor` / `aria-*` + `anchor-name`)
// carries different `cn-button-variant-*` / `cn-button-size-*` classes per call.

pub fn trigger_outline_medium_test() {
  popover.trigger(
    handle(),
    variant: button.Outline,
    size: button.Medium,
    attrs: [],
    children: [
      html.text("Open"),
    ],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui popover trigger — outline / medium")
}

pub fn trigger_destructive_lg_test() {
  popover.trigger(
    handle(),
    variant: button.Destructive,
    size: button.Lg,
    attrs: [],
    children: [
      html.text("Open"),
    ],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui popover trigger — destructive / lg")
}

pub fn trigger_ghost_sm_test() {
  popover.trigger(
    handle(),
    variant: button.Ghost,
    size: button.Sm,
    attrs: [],
    children: [
      html.text("Open"),
    ],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui popover trigger — ghost / sm")
}

// --- content: dismiss is honored -----------------------------------------
//
// `dismiss` maps to the native `popover` attribute: `Auto` → `popover="auto"`
// (light-dismiss), `Manual` → `popover="manual"` (host-owned). Same call,
// different value, different rendered attribute.

pub fn content_auto_dismiss_test() {
  let pop = handle()
  popover.content(
    pop,
    side: positioning.Bottom,
    align: positioning.Center,
    padding: popover.Padded,
    dismiss: popover.Auto,
    arrow: False,
    on_toggle: None,
    attrs: [],
    children: [popover.title(pop, [], [html.text("Title")])],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui popover content — auto dismiss")
}

pub fn content_manual_dismiss_test() {
  let pop = handle()
  popover.content(
    pop,
    side: positioning.Bottom,
    align: positioning.Center,
    padding: popover.Padded,
    dismiss: popover.Manual,
    arrow: False,
    on_toggle: None,
    attrs: [],
    children: [popover.title(pop, [], [html.text("Title")])],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui popover content — manual dismiss")
}

// --- content: padding (the date-picker enabler) --------------------------
//
// `Padded` (default) renders the text-popover box (`cn-popover cn-popover-padded`
// — fixed width + padding). `Unpadded` drops to the bare surface (`cn-popover`
// only — auto width, no padding) for content that brings its own box, e.g. a
// calendar in the date picker. `attrs` merge onto the card.

pub fn content_unpadded_test() {
  let pop = handle()
  popover.content(
    pop,
    side: positioning.Bottom,
    align: positioning.Start,
    padding: popover.Unpadded,
    dismiss: popover.Auto,
    arrow: False,
    on_toggle: None,
    attrs: [],
    children: [popover.title(pop, [], [html.text("Title")])],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui popover content — unpadded (bare surface)")
}

// --- content: arrow markup is geometry-free ------------------------------
//
// With `arrow: True` the content renders the decorative caret. Its per-side
// geometry (size, `viewBox`, `d`, `position-area`, offset) now lives entirely
// in CSS keyed on the popup's `data-side` — so this pins that the rendered SVG
// is "dumb": a `[data-arrow]` marker, the two `[data-arrow-part]` paths with no
// `d`, and only the dynamic inline anchoring (`position: fixed` +
// `position-anchor`). No width/height/viewBox/d/data-side on the node.

pub fn content_with_arrow_test() {
  let pop = handle()
  popover.content(
    pop,
    side: positioning.Bottom,
    align: positioning.Center,
    padding: popover.Padded,
    dismiss: popover.Auto,
    arrow: True,
    on_toggle: None,
    attrs: [],
    children: [popover.title(pop, [], [html.text("Title")])],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui popover content — with arrow")
}

// --- terse: Options defaults + record-update spread ----------------------
//
// `popover.options()` resolves all defaults (bottom/end, no arrow, light-
// dismiss); record-update overrides only what's passed — here a deterministic
// id so the snapshot is stable. Pins the default placement (`data-side="bottom"`
// / `data-align="end"`) and `popover="auto"`.

pub fn terse_defaults_test() {
  popover.popover(
    options: popover.Options(..popover.options(), id: Some("demo")),
    children: fn(pop) { [popover.title(pop, [], [html.text("Title")])] },
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui popover terse — defaults (bottom/end, auto)")
}

// `popover_with_trigger` takes a caller-supplied trigger element (here a plain
// `<button>` carrying `trigger_attributes`); the `text`/`variant`/`size` in
// `options` don't apply, while placement/dismiss/id still do.
pub fn terse_custom_trigger_test() {
  popover.popover_with_trigger(
    trigger: fn(pop) {
      html.button(popover.trigger_attributes(pop), [html.text("Custom")])
    },
    options: popover.Options(..popover.options(), id: Some("demo")),
    children: fn(pop) { [popover.title(pop, [], [html.text("Title")])] },
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui popover terse — custom trigger callback")
}

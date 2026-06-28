import birdie
import gg_ui/ui/button
import gg_ui/ui/dialog
import gleam/option.{None, Some}
import lustre/element
import lustre/element/html

// A deterministic handle so the rendered ids are stable across runs (a
// generated base id would churn the snapshot every time).
fn handle() -> dialog.Anatomy {
  dialog.anatomy_with_id("demo")
}

// --- trigger: button props are honored -----------------------------------
//
// The styled `trigger` forwards the `variant` / `size` it's handed to the
// underlying `Button`, while the same headless trigger behaviour
// (`command="show-modal"` / `commandfor` / `aria-*`) rides along.

pub fn trigger_outline_medium_test() {
  dialog.trigger(
    handle(),
    variant: button.Outline,
    size: button.Medium,
    attrs: [],
    children: [
      html.text("Open"),
    ],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui dialog trigger — outline / medium")
}

pub fn trigger_destructive_lg_test() {
  dialog.trigger(
    handle(),
    variant: button.Destructive,
    size: button.Lg,
    attrs: [],
    children: [html.text("Delete")],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui dialog trigger — destructive / lg")
}

// --- content: dismiss + role are honored ---------------------------------
//
// `dismiss` maps to the native `closedby` attribute (`any` / `closerequest` /
// `none`); `role` upgrades the native `<dialog>` to `alertdialog`. Same call,
// different value, different rendered attribute.

pub fn content_light_dismiss_test() {
  let d = handle()
  dialog.content(
    d,
    dismiss: dialog.LightDismiss,
    role: dialog.Standard,
    on_close: None,
    attrs: [],
    children: [dialog.title(d, [html.text("Title")])],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui dialog content — light dismiss")
}

pub fn content_manual_alert_test() {
  let d = handle()
  dialog.content(
    d,
    dismiss: dialog.Manual,
    role: dialog.AlertDialog,
    on_close: None,
    attrs: [],
    children: [
      dialog.title(d, [html.text("Delete file?")]),
      dialog.description(d, [html.text("This cannot be undone.")]),
    ],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui dialog content — manual / alertdialog")
}

// --- close parts ----------------------------------------------------------

pub fn close_button_test() {
  dialog.close(
    handle(),
    variant: button.Outline,
    size: button.Medium,
    attrs: [],
    children: [
      html.text("Cancel"),
    ],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui dialog close — outline button")
}

pub fn close_icon_test() {
  dialog.close_icon(handle())
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui dialog close — corner icon")
}

// --- terse: Options defaults + record-update spread ----------------------
//
// `dialog.options()` resolves all defaults (outline trigger, light-dismiss,
// standard role, corner ✕ shown); record-update overrides only what's passed —
// here a deterministic id so the snapshot is stable.

pub fn terse_defaults_test() {
  dialog.dialog(
    options: dialog.Options(..dialog.options(), id: Some("demo")),
    children: fn(d) {
      [
        dialog.header([], [
          dialog.title(d, [html.text("Title")]),
          dialog.description(d, [html.text("Description text here.")]),
        ]),
      ]
    },
  )
  |> element.to_readable_string
  |> birdie.snap(
    title: "gg_ui dialog terse — defaults (light-dismiss, corner ✕)",
  )
}

// `dialog_with_trigger` takes a caller-supplied trigger element (here a plain
// `<button>` carrying `trigger_attributes`); the `text`/`variant`/`size` in
// `options` don't apply, while dismiss/role/id/close-button still do. Here the
// corner ✕ is turned off.
pub fn terse_custom_trigger_no_close_test() {
  dialog.dialog_with_trigger(
    trigger: fn(d) {
      html.button(dialog.trigger_attributes(d), [html.text("Custom")])
    },
    options: dialog.Options(
      ..dialog.options(),
      id: Some("demo"),
      close_button: False,
    ),
    children: fn(d) { [dialog.title(d, [html.text("Title")])] },
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui dialog terse — custom trigger, no corner ✕")
}

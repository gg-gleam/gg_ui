//// Headless button primitive — a Lustre port of Base UI's `Button`
//// (`@base-ui/react/button`).
////
//// Base UI's Button is `useButton` (behavior) + `useRenderElement` (the render
//// pattern). `useButton` supplies the props a button needs and `useRenderElement`
//// merges them onto either the default `<button>` or a `render` element. The
//// props it supplies depend on the target: a native `<button>` gets `type` and
//// the HTML `disabled` attribute; a non-native element (e.g. a styled `<div>`)
//// gets `role="button"`, `tabindex`, and `aria-disabled` so AT and the tab order
//// behave correctly.
////
//// We mirror that split. `attributes(config, target)` is the `useButton`
//// equivalent: a list of behavior attributes you merge onto whatever element you
//// render. `button` is the convenience that renders the default `<button>` with
//// `attributes(config, Native)`. Styling lives one layer up (e.g.
//// `ui/button`).
////
//// `focusable_when_disabled` matches Base UI: a disabled-but-focusable control
//// keeps `aria-disabled` instead of `disabled` (Native) or keeps `tabindex="0"`
//// (NonNative), so it stays in the tab order (e.g. to keep a tooltip reachable).
////
//// Note: a fully-faithful NonNative port would also synthesize Space/Enter
//// keyboard activation. That requires hooking Lustre event dispatch and is left
//// to callers for now.

import gleam/list
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html

pub type Config {
  Config(disabled: Bool, focusable_when_disabled: Bool)
}

/// Which element the headless props will be merged onto. `Native` is a real
/// `<button>` (implicit button semantics, supports HTML `disabled`). `NonNative`
/// is anything else acting as a button (`<a>`, `<div>`, `<span>`, …) and needs
/// `role="button"`, `tabindex`, and `aria-disabled` synthesized.
///
/// An `<a href>` styled as a button is `NonNative` too: Base UI's `useButton`
/// applies the same `role`/`tabindex`/`aria-disabled` to it (`native: false`).
/// The one anchor-specific nuance is *activation* — a valid link is driven by
/// the browser's native Enter handling rather than synthesized Space/Enter — but
/// the attribute set is identical, so `NonNative` is the right target.
pub type Target {
  Native
  NonNative
}

/// Defaults matching Base UI: enabled, not focusable-when-disabled.
pub fn config() -> Config {
  Config(disabled: False, focusable_when_disabled: False)
}

/// The `useButton`/`getButtonProps` equivalent. Returns the behavior attributes
/// to merge onto the target element.
pub fn attributes(
  config config: Config,
  target target: Target,
) -> List(Attribute(msg)) {
  case target {
    Native -> native_attributes(config)
    NonNative -> non_native_attributes(config)
  }
}

fn native_attributes(config: Config) -> List(Attribute(msg)) {
  list.flatten([
    [attribute.type_("button")],
    case config.disabled, config.focusable_when_disabled {
      False, _ -> []
      True, False -> [attribute.disabled(True)]
      True, True -> [attribute.attribute("aria-disabled", "true")]
    },
  ])
}

fn non_native_attributes(config: Config) -> List(Attribute(msg)) {
  let tabindex = case config.disabled, config.focusable_when_disabled {
    True, False -> "-1"
    _, _ -> "0"
  }
  list.flatten([
    [
      attribute.attribute("role", "button"),
      attribute.attribute("tabindex", tabindex),
    ],
    case config.disabled {
      True -> [attribute.attribute("aria-disabled", "true")]
      False -> []
    },
  ])
}

pub fn button(
  config config: Config,
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  html.button(
    list.flatten([attributes(config:, target: Native), attrs]),
    children,
  )
}

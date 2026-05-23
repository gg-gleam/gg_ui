//// Headless popover, native-first.
////
//// Layering + dismissal use the native [Popover
//// API](https://developer.mozilla.org/en-US/docs/Web/API/Popover_API): the
//// content carries `popover="auto"`, so the browser puts it in the **top
//// layer** (escaping any `overflow`/`transform` clipping — no portal needed)
//// and handles light-dismiss (outside-click + Escape) for free. Positioning is
//// delegated to `gg_ui/core/positioning` (native CSS anchor positioning).
////
//// Open/close is **configurable**:
//// - Declarative (default): pair `anchor` (a `popovertarget` button) with
////   `content`. The browser owns the toggle; `content` reports state changes
////   through `on_toggle` so your model can mirror them. No JS.
//// - Controlled: use `anchor_controlled` + `set_open` to drive it from your
////   own state via the imperative `showPopover`/`hidePopover` escape hatch.

import gg_ui/core/positioning.{type Placement}
import gleam/dynamic/decode
import lustre/attribute.{type Attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

// --- State ---------------------------------------------------------------

pub type State {
  State(open: Bool, anchor_id: String, content_id: String)
}

pub fn init(id: String) -> State {
  State(open: False, anchor_id: id <> "-anchor", content_id: id <> "-content")
}

pub type Msg {
  Opened
  Closed
  Toggled
  DismissRequested
}

pub fn update(state: State, msg: Msg) -> State {
  case msg {
    Opened -> State(..state, open: True)
    Closed -> State(..state, open: False)
    Toggled -> State(..state, open: !state.open)
    DismissRequested -> State(..state, open: False)
  }
}

pub fn is_open(state: State) -> Bool {
  state.open
}

// --- View: declarative (browser-driven) ----------------------------------

/// Declarative trigger: a `popovertarget` button that also names itself as the
/// positioning anchor. The browser toggles the popover; no handler needed.
pub fn anchor(
  state: State,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.button(
    [
      attribute.id(state.anchor_id),
      attribute.attribute("popovertarget", state.content_id),
      attribute.attribute("popovertargetaction", "toggle"),
      positioning.anchor_style(state.anchor_id),
      ..attrs
    ],
    children,
  )
}

/// The floating content. Always rendered (the browser shows/hides it via the
/// top layer), so it round-trips through SSR. `on_toggle` receives the new open
/// state from the native `toggle` event — wire it to a message that mirrors the
/// flag in your model.
pub fn content(
  state: State,
  placement: Placement,
  on_toggle: fn(Bool) -> msg,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.div(
    [
      attribute.id(state.content_id),
      attribute.attribute("popover", "auto"),
      positioning.positioned_style(state.anchor_id, placement),
      event.on("toggle", toggle_handler(on_toggle)),
      ..attrs
    ],
    children,
  )
}

fn toggle_handler(on_toggle: fn(Bool) -> msg) -> decode.Decoder(msg) {
  use new_state <- decode.field("newState", decode.string)
  decode.success(on_toggle(new_state == "open"))
}

// --- View + effects: controlled (app-driven) -----------------------------

/// Controlled trigger: a plain button (still the positioning anchor) that
/// dispatches `on_click`. Pair with `set_open` to drive the popover from your
/// own state — needed for things like a combobox that opens on focus/typing.
pub fn anchor_controlled(
  state: State,
  on_click: msg,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.button(
    [
      attribute.id(state.anchor_id),
      event.on_click(on_click),
      positioning.anchor_style(state.anchor_id),
      ..attrs
    ],
    children,
  )
}

@external(javascript, "/src/gg_ui/core/popover_ffi", "showPopover")
fn show_popover(_content_id: String) -> Nil {
  Nil
}

@external(javascript, "/src/gg_ui/core/popover_ffi", "hidePopover")
fn hide_popover(_content_id: String) -> Nil {
  Nil
}

/// Imperatively reconcile the native popover with your `open` flag. JS-only;
/// the Erlang fallbacks never run because effects execute client-side.
pub fn set_open(state: State, open: Bool) -> Effect(msg) {
  effect.from(fn(_dispatch) {
    case open {
      True -> show_popover(state.content_id)
      False -> hide_popover(state.content_id)
    }
  })
}

//// The popover's client-only layer: Floating UI positioning and outside-click
//// / Escape dismissal, wired through a single `sync` effect.
////
//// Every binding carries a Gleam fallback body so the package still compiles
//// on the Erlang target (the "universal" promise). Those bodies never run in
//// practice: `sync` is a Lustre `effect`, and effects only execute in the
//// client runtime, where the JS `@external` implementations take over.

import gg_ui/popover.{type Placement, type State, placement_to_string}
import lustre/effect.{type Effect}

// --- FFI (JS only; Erlang fallbacks keep the universal target compiling) ---

@external(javascript, "/src/gg_ui/popover_ffi", "startPositioning")
fn start_positioning(
  _anchor_id: String,
  _content_id: String,
  _placement: String,
) -> Nil {
  Nil
}

@external(javascript, "/src/gg_ui/popover_ffi", "stopPositioning")
fn stop_positioning(_content_id: String) -> Nil {
  Nil
}

@external(javascript, "/src/gg_ui/popover_ffi", "startDismiss")
fn start_dismiss(
  _anchor_id: String,
  _content_id: String,
  _on_dismiss: fn() -> Nil,
) -> Nil {
  Nil
}

@external(javascript, "/src/gg_ui/popover_ffi", "stopDismiss")
fn stop_dismiss(_content_id: String) -> Nil {
  Nil
}

// --- Effect --------------------------------------------------------------

/// Reconcile the DOM side-effects with the popover's `open` flag. Run this from
/// your `update` whenever the popover state changes:
///
/// - open  → start Floating UI auto-positioning + dismissal listeners.
/// - close → tear both down.
///
/// `on_dismiss` is the message dispatched when the user clicks outside or
/// presses Escape; it's generic over your app's `msg` type.
pub fn sync(
  state: State,
  placement: Placement,
  on_dismiss: msg,
) -> Effect(msg) {
  effect.from(fn(dispatch) {
    case state.open {
      True -> {
        let _ =
          start_positioning(
            state.anchor_id,
            state.content_id,
            placement_to_string(placement),
          )
        start_dismiss(state.anchor_id, state.content_id, fn() {
          dispatch(on_dismiss)
        })
      }
      False -> {
        let _ = stop_positioning(state.content_id)
        stop_dismiss(state.content_id)
      }
    }
  })
}

//// Headless popover — the pure, universal core.
////
//// This module owns only the open/closed status, the element ids used for
//// ARIA wiring, and the unstyled view builders. It has **no FFI and touches no
//// DOM**, so it compiles on every Gleam target and is unit-testable in
//// isolation. Positioning (Floating UI), outside-click / Escape dismissal and
//// portalling all live in `gg_ui/popover/positioning`, which is the only
//// client-only piece.

import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html

// --- State ---------------------------------------------------------------

pub type State {
  State(open: Bool, anchor_id: String, content_id: String)
}

/// `id` seeds stable, unique element ids for the anchor and content so the
/// positioning layer can find them in the DOM.
pub fn init(id: String) -> State {
  State(open: False, anchor_id: id <> "-anchor", content_id: id <> "-content")
}

pub type Msg {
  Opened
  Closed
  Toggled
  /// Outside-click or Escape asked the popover to dismiss.
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

// --- Placement -----------------------------------------------------------

/// A subset of Floating UI placements, kept type-safe on the Gleam side. The
/// FFI layer turns these into the strings Floating UI expects.
pub type Placement {
  Top
  Bottom
  Left
  Right
  BottomStart
  BottomEnd
}

pub fn placement_to_string(placement: Placement) -> String {
  case placement {
    Top -> "top"
    Bottom -> "bottom"
    Left -> "left"
    Right -> "right"
    BottomStart -> "bottom-start"
    BottomEnd -> "bottom-end"
  }
}

// --- Unstyled view builders ----------------------------------------------

/// The anchor the content is positioned against. Carries `anchor_id` and
/// spreads any caller attributes/children — the styled layer decides what it
/// looks like.
pub fn anchor(
  state: State,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.div([attribute.id(state.anchor_id), ..attrs], children)
}

/// The floating content. Rendered only while open so the positioning layer has
/// a real element to measure, and torn down on close.
pub fn content(
  state: State,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  case state.open {
    False -> element.none()
    True ->
      html.div(
        [attribute.id(state.content_id), attribute.role("dialog"), ..attrs],
        children,
      )
  }
}

import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

// A scrollable demo surface for collision / positioning stories: an oversized
// inner canvas with a faint, theme-aware grid and a single trigger centered in
// it. The `content` (top-layer popup) renders as a sibling so it escapes into
// the top layer when open. Shared so the popover and (later) tooltip collision
// stories render the exact same surface.

/// Stable id on the scroll container so a story's `play` can grab the scroller
/// directly, without keying off inline styles.
pub const scroll_area_id = "story-scroll-canvas"

/// The scrollable surface. `trigger` sits at the center of the oversized grid;
/// `content` (the top-layer popup) renders as a sibling so it escapes into the
/// top layer when open.
///
/// Geometry + grid live in the `.story-canvas*` classes (`src/css/story-canvas.css`)
/// rather than Tailwind arbitrary utilities — see that file for why.
/// `.story-canvas` is `position: fixed; inset: 0`, so the surface pins to the
/// viewport edges with no gap; `bg-background`/`text-foreground` keep it
/// on-theme in light and dark.
pub fn scroll_canvas(
  trigger trigger: Element(msg),
  content content: Element(msg),
) -> Element(msg) {
  html.div([], [
    html.div(
      [
        attribute.id(scroll_area_id),
        attribute.class("story-canvas bg-background text-foreground"),
      ],
      [
        html.div([attribute.class("story-canvas-grid")], [
          html.div([attribute.class("story-canvas-trigger")], [trigger]),
        ]),
      ],
    ),
    content,
  ])
}

@external(javascript, "./scroll_canvas_ffi.ts", "centerInScrollArea")
fn center_in_scroll_area(_trigger_id: String, on_done: fn() -> Nil) -> Nil {
  on_done()
}

/// Scroll the trigger to the center of the canvas after the first paint — a
/// reliable replacement for leaning on `autofocus` to bring it into view. Wire
/// into a `lustre.application` `init` (the surface needs an app, not a static
/// element, to run an effect). `trigger_id` is the trigger's DOM id — for a
/// popover that's `anatomy.anchor_id`.
///
/// `on_centered` is dispatched once the scroll has settled. Open a popup from
/// there (not in parallel) so its side resolves against the *centered* trigger
/// rather than its initial off-screen position.
pub fn center_effect(trigger_id: String, on_centered: msg) -> Effect(msg) {
  effect.after_paint(fn(dispatch, _root) {
    center_in_scroll_area(trigger_id, fn() { dispatch(on_centered) })
  })
}

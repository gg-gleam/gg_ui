//// Shared positioning primitive — anchor a floating element to a reference.
////
//// This is the piece popover, and later tooltip/menu/select, all build on. It
//// is **pure**: it only produces CSS, using native [CSS Anchor
//// Positioning](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_anchor_positioning)
//// (`anchor-name` / `position-anchor` / `position-area` / `position-try`). No
//// FFI, no DOM, no JS — so it compiles on every target and works server-side.
////
//// Native anchor positioning is Chromium-first today; a Floating UI strategy
//// can slot in behind this same API later for cross-browser support without
//// touching the components that consume it.

import lustre/attribute.{type Attribute}

pub type Side {
  Top
  Right
  Bottom
  Left
}

pub type Align {
  Start
  Center
  End
}

pub type Placement {
  Placement(side: Side, align: Align)
}

/// A dashed-ident `anchor-name`, derived from the anchor element's id so each
/// instance is unique and the two sides agree on the same name.
pub fn anchor_name(anchor_id: String) -> String {
  "--gg-" <> anchor_id
}

/// Goes on the reference element (the trigger): names it as an anchor.
pub fn anchor_style(anchor_id: String) -> Attribute(msg) {
  attribute.styles([#("anchor-name", anchor_name(anchor_id))])
}

/// Goes on the floating element: tethers it to the anchor, places it on the
/// requested side/alignment, and lets the browser flip it on collision.
pub fn positioned_style(
  anchor_id: String,
  placement: Placement,
) -> Attribute(msg) {
  attribute.styles([
    #("position", "fixed"),
    #("position-anchor", anchor_name(anchor_id)),
    #("position-area", position_area(placement)),
    #("position-try-fallbacks", "flip-block, flip-inline"),
    #("position-visibility", "anchors-visible"),
    #("inset", "auto"),
    gap(placement.side),
  ])
}

/// Map a side+align to a `position-area`. `span-inline-end` keeps the element's
/// start edge aligned with the anchor's, etc.
fn position_area(placement: Placement) -> String {
  case placement.side, placement.align {
    Top, Start -> "top span-inline-end"
    Top, Center -> "top"
    Top, End -> "top span-inline-start"
    Bottom, Start -> "bottom span-inline-end"
    Bottom, Center -> "bottom"
    Bottom, End -> "bottom span-inline-start"
    Left, Start -> "left span-block-end"
    Left, Center -> "left"
    Left, End -> "left span-block-start"
    Right, Start -> "right span-block-end"
    Right, Center -> "right"
    Right, End -> "right span-block-start"
  }
}

/// A small gap between anchor and floating element, on the facing side only.
fn gap(side: Side) -> #(String, String) {
  let size = "0.375rem"
  case side {
    Top -> #("margin-bottom", size)
    Bottom -> #("margin-top", size)
    Left -> #("margin-right", size)
    Right -> #("margin-left", size)
  }
}

//// Shared positioning primitive — anchor a floating element to a reference.
////
//// This is the piece popover, and later tooltip/menu/select, all build on. It
//// is **pure behavior**: it produces only *functional* positioning as **inline
//// styles** (native [CSS Anchor
//// Positioning](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_anchor_positioning)),
//// the way Base UI's Positioner emits inline layout styles. It depends on **no
//// Tailwind and no stylesheet** — only `lustre`. Visual styling (and the choice
//// of how big the offset is) belongs to the `ui/`/styles layer; this layer just
//// sets the load-bearing positioning properties and exposes `data-side` /
//// `data-align` hooks (via `popover`) for that layer to key on.

import gleam/int
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
/// requested side/alignment, applies the offset, and lets the browser flip it
/// on collision. All emitted as **inline styles** — no Tailwind.
///
/// We must reset both `inset` and `margin` from the UA `[popover]` rules.
/// `position-area` only swaps the *containing block* to the chosen grid cell —
/// it's a different property than `inset`, so the UA's `[popover] { inset: 0 }`
/// survives the cascade and resolves against that cell, pinning the popup to
/// all four edges (stretched to fill the cell) and cancelling content-sizing
/// and our margin offset. `inset: auto` lets the popup self-align within the
/// cell instead. Mirrors Chrome's guidance (`[popover] { inset: auto }`).
///
/// `side_offset` is the gap, **in pixels**, between anchor and popup on the
/// facing side — a *neutral* unit. The `ui/`/shape layer decides the value
/// (e.g. nova passes `8`); this primitive never bakes in a number or a Tailwind
/// scale. It's applied as a margin on whichever axis faces the anchor, so
/// callers pass one number and don't think about top/right/bottom/left.
pub fn positioned_style(
  anchor_id: String,
  placement: Placement,
  side_offset: Int,
) -> List(Attribute(msg)) {
  [
    attribute.styles([
      #("position-anchor", anchor_name(anchor_id)),
      #("position-area", position_area_value(placement)),
      #("inset", "auto"),
      #("position-try-fallbacks", position_try_fallbacks),
      ..offset_styles(placement.side, side_offset)
    ]),
  ]
}

// Flip only on the block axis (the natural opposite side) and inline alignment —
// never `flip-start`, which swaps the *whole axis* (a bottom dropdown thrown out
// to the right when it doesn't fit below). A tall popup that can't fit below
// opens upward instead, the expected overlay behaviour.
const position_try_fallbacks = "flip-block, flip-inline, flip-block flip-inline"

pub fn side_to_string(side: Side) -> String {
  case side {
    Top -> "top"
    Right -> "right"
    Bottom -> "bottom"
    Left -> "left"
  }
}

/// Lowercase token for a `data-align` attribute (matches Base UI).
pub fn align_to_string(align: Align) -> String {
  case align {
    Start -> "start"
    Center -> "center"
    End -> "end"
  }
}

/// The `position-area` value (a raw CSS value, not a Tailwind class) for a
/// placement. Stays within the *logical* keyword group — never mixing physical
/// (`top`/`right`/…) with logical spans (`span-inline-*`), which CSS drops
/// wholesale.
pub fn position_area_value(placement: Placement) -> String {
  case placement.side, placement.align {
    Top, Start -> "block-start span-inline-end"
    Top, Center -> "block-start"
    Top, End -> "block-start span-inline-start"
    Bottom, Start -> "block-end span-inline-end"
    Bottom, Center -> "block-end"
    Bottom, End -> "block-end span-inline-start"
    Left, Start -> "inline-start span-block-end"
    Left, Center -> "inline-start"
    Left, End -> "inline-start span-block-start"
    Right, Start -> "inline-end span-block-end"
    Right, Center -> "inline-end"
    Right, End -> "inline-end span-block-start"
  }
}

/// The offset margin, as inline styles: the gap goes on the axis that faces the
/// anchor (block for top/bottom, inline for left/right); the other axis is 0.
fn offset_styles(side: Side, offset: Int) -> List(#(String, String)) {
  let px = int.to_string(offset) <> "px"
  case side {
    Top | Bottom -> [#("margin-inline", "0"), #("margin-block", px)]
    Left | Right -> [#("margin-block", "0"), #("margin-inline", px)]
  }
}

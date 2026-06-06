//// Arrow primitive — an SVG triangle anchored to a trigger element, used by
//// popovers (and tooltips, menus, … later) as the visual tail connecting the
//// floating panel to its trigger.
////
//// The arrow positions itself entirely through CSS Anchor Positioning: it's
//// `position: fixed` (so its containing block is the viewport, which is what
//// `anchor()` / `position-area` require to resolve when the element sits
//// inside a top-layer popover) and shares the same `position-anchor` as the
//// popup. Everything *per-side* — `position-area`, `align-self`/`justify-self`,
//// the caret `<path>` geometry (`d`), `width`/`height`, and the trigger-ward
//// offset margin — lives in CSS keyed on the popup's resolved `data-side`
//// (`styles/shapes/arrow.css`), not here. This module ships only the two
//// load-bearing, *dynamic* inline styles (`position: fixed` and the per-anchor
//// `position-anchor`) plus the markup the CSS hooks onto.
////
//// **Geometry is the stylesheet's job; this is markup + anchoring only.** The
//// `<svg>` carries no `width`/`height`/`viewBox`/`d` — CSS supplies them (no
//// viewBox → 1 user unit = 1px). The fill `<path>`'s `fill` inherits down from
//// the SVG-level `fill`, and the stroke `<path>` sets `fill="none"` so only its
//// outline paints — so a single `fill-X stroke-Y` on the `<svg>` (passed via
//// `attrs`) is enough to skin it.
////
//// Why no `placement` argument: the caret never depended on `align`, and its
//// `side` is now read from the popup's `data-side` by CSS — so the arrow node
//// itself is "dumb" and identical regardless of where the popup opens. The
//// popup's `data-side` (present at first paint, rewritten by the flip observer)
//// drives the whole appearance.

import gg_base_ui/positioning/positioning.{anchor_name}
import gleam/list
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/svg

/// Goes on the arrow's `<svg>`. Anchors it to the trigger named `anchor_id`
/// (the same anchor the popup uses) via `position: fixed` + `position-anchor`.
/// The per-side cell (`position-area`) and pinning (`align-self` /
/// `justify-self`) live in CSS keyed on the popup's `data-side`; only these two
/// dynamic properties are inline.
///
/// `position: fixed` is load-bearing, not arbitrary. Per W3C CSS Anchor
/// Positioning Level 1 §3.4, `anchor()` / `position-area` only resolve when
/// the positioned element's containing block is the initial containing block
/// (the viewport). The arrow is a DOM child of a top-layer popover; with
/// `position: absolute`, its CB would be the popup itself (the trigger isn't a
/// descendant of the popup, so anchoring fails). `fixed` makes the CB the
/// viewport, satisfying the rule.
pub fn anchored_style(anchor_id: String) -> List(Attribute(msg)) {
  [
    attribute.styles([
      #("position", "fixed"),
      #("pointer-events", "none"),
      #("position-anchor", anchor_name(anchor_id)),
    ]),
  ]
}

/// Render the arrow as an `<svg>` with a fill-only `<path>` plus a stroke-only
/// `<path>` for the two non-base edges (the `data-arrow-part` attribute tags
/// each so the CSS in `styles/shapes/arrow.css` can give it the right `d` per
/// side). Splitting fill and stroke across two shapes is what keeps the caret's
/// *base* unstroked: the stroke path is open through the two diagonals (with the
/// rounded apex), so the base never gets a stroke — and the fill path paints
/// over the popup's own border in the arrow's width, so the popup outline "lifts
/// up" into the arrow instead of drawing a flat line across the seam.
///
/// No `width`/`height`/`viewBox`/`d` here — all per-side geometry is CSS, keyed
/// on the popup's `data-side`. `[data-arrow]` is the marker that CSS (and any
/// future tooling) hooks onto; it lets selectors find this arrow without
/// matching unrelated SVGs in the popover body. `attrs` is appended last and
/// wins on conflict — pass `fill-*` / `stroke-*` / `--arrow-offset` overrides
/// there.
///
/// Side-effect: installs the document-scope observer that keeps the popup's
/// `data-side` in sync with the resolved side after any
/// `position-try-fallbacks` flip — the only thing CSS can't do. CSS keys both
/// the arrow geometry and the styled layer's flip-away hiding off that one
/// attribute. Idempotent; only the first call actually attaches listeners.
pub fn arrow(anchor_id: String, attrs: List(Attribute(msg))) -> Element(msg) {
  let Nil = ensure_resolved_side_observer()
  svg.svg(
    list.flatten([
      [
        attribute.attribute("aria-hidden", "true"),
        // Marker the geometry CSS keys on (`[data-side] [data-arrow]`), and a
        // stable hook for tooling/tests. Lets selectors find the arrow inside
        // the popup without matching unrelated SVGs the user may have placed in
        // the popover body. (The flip observer does *not* use it — it keys off
        // the popup's `[popover]` element and only writes `data-side`.)
        attribute.attribute("data-arrow", ""),
        attribute.attribute("overflow", "visible"),
      ],
      anchored_style(anchor_id),
      attrs,
    ]),
    [
      svg.path([
        attribute.attribute("data-arrow-part", "fill"),
        attribute.attribute("stroke", "none"),
      ]),
      svg.path([
        attribute.attribute("data-arrow-part", "stroke"),
        attribute.attribute("fill", "none"),
        attribute.attribute("stroke-linejoin", "round"),
      ]),
    ],
  )
}

// --- Resolved-side observer install ------------------------------------------

@external(javascript, "./arrow_ffi.ts", "ensureResolvedSideObserver")
fn ensure_resolved_side_observer() -> Nil {
  Nil
}

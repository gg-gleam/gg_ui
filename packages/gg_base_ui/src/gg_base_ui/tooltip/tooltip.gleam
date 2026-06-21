//// Headless tooltip, native-first — a Lustre port of Base UI's `Tooltip.*`
//// anatomy.
////
//// Base UI exposes the tooltip as composable parts (`Provider`, `Root`,
//// `Trigger`, `Portal`, `Positioner`, `Popup`, `Arrow`). We mirror that surface,
//// but lean on web platform primitives instead of a JS runtime — exactly as the
//// sibling `gg_base_ui/popover` does, only the *open trigger* differs: a popover
//// is opened by a click ([Invoker Commands](https://developer.mozilla.org/en-US/docs/Web/API/Invoker_Commands_API)),
//// a tooltip by *interest* (hover / focus / long-press).
////
//// - **No Root state in the host model.** The native [Popover
////   API](https://developer.mozilla.org/en-US/docs/Web/API/Popover_API), in its
////   `popover="hint"` flavour, makes the browser the source of truth for `open`.
////   `Anatomy` is just the two stable IDs the parts need; no `Bool` lives in
////   Gleam-land.
//// - **Hover / focus / long-press + delay** use the [Interest Invoker
////   API](https://developer.mozilla.org/en-US/docs/Web/API/Popover_API/Using_interest_invokers):
////   the trigger carries `interestfor="<content-id>"`, and the browser shows the
////   hint when the user shows interest (hover, keyboard focus, or touch
////   long-press) and hides it when interest is lost — no `mouseenter`/`focus`/
////   timer JS. The open/close *delays* are the native CSS `interest-delay-start`
////   / `interest-delay-end` properties, emitted inline on the trigger so each
////   instance can tune them (Base UI's `delay` / `closeDelay`).
//// - **Layering + dismissal** come from `popover="hint"`: the browser puts the
////   hint in the **top layer** (escaping `overflow`/`transform` clipping — so
////   Base UI's `Portal` is unnecessary), shows only one hint at a time, and
////   light-dismisses (Escape, outside interaction) for free. The hint is also
////   *hoverable* and *persistent* per WCAG 1.4.13 — all native.
//// - **Positioner + Popup** collapse onto one element positioned by
////   `gg_base_ui/positioning` (native CSS anchor positioning), shared verbatim
////   with the popover.
//// - **Arrow** is the shared `gg_base_ui/arrow` primitive, anchored to the
////   trigger and keyed on the popup's resolved `data-side`.
//// - **Visual open/closed styling** comes from the native `:popover-open` CSS
////   pseudo-class — no `data-open`/`data-closed` mirror to keep in sync.
////
//// **ARIA.** Interest invokers wire `role="tooltip"` and the trigger↔hint
//// `aria-describedby` association natively in supporting browsers, but we *also*
//// emit them explicitly: it is the time-tested, universally-supported tooltip
//// pattern, it round-trips through SSR, and it degrades gracefully where interest
//// invokers aren't implemented yet. The explicit `aria-describedby` points at the
//// same id the native association would use, so the two never conflict.
////
//// Deliberately out of scope (matching popover): the JS-runtime extras — a
//// provider's shared/grouped delay window, cursor tracking, and a `Viewport` for
//// multi-trigger transitions. They can layer on later behind these same parts.

import gg_base_ui/arrow/arrow
import gg_base_ui/helpers/id_gen/id_gen
import gg_base_ui/positioning/positioning.{type Placement, anchor_name}
import gleam/int
import gleam/list
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html

// --- Anatomy -------------------------------------------------------------

/// Stable IDs the two parts share — the trigger's anchor id and the hint's
/// content id (referenced by `interestfor` and `aria-describedby`), both derived
/// from one base.
///
/// **Construct once and reuse** — generate it once at the top of a render-once
/// static view (or in `init` and keep it in your model), then thread it through
/// `trigger` / `popup`. Do **not** call `anatomy()` inside a re-rendering `view`:
/// it mints a fresh base each call (see `id_gen`), which would change the ids out
/// from under the `interestfor` link they wire.
pub type Anatomy {
  Anatomy(anchor_id: String, content_id: String)
}

/// Build an `Anatomy` with a freshly-generated, collision-free base id — the
/// default. Callers never invent or expose an id, so two tooltips on the same
/// page can't clash. The `useId` analogue (see `gg_base_ui/helpers/id_gen/id_gen`):
/// call **once** per tooltip and reuse the result; never recompute it per render.
pub fn anatomy() -> Anatomy {
  anatomy_with_id(id_gen.generate_with_prefix("tooltip"))
}

/// Build an `Anatomy` from an explicit, caller-chosen base id. Escape hatch for
/// when the id must be deterministic — tests, or pinning ids across a
/// server/client render boundary. Prefer `anatomy()` otherwise so ids stay an
/// internal detail. The caller owns uniqueness. Safe to call in `view` *and*
/// `update` (it's a pure id derivation).
pub fn anatomy_with_id(id: String) -> Anatomy {
  Anatomy(anchor_id: id <> "-anchor", content_id: id <> "-content")
}

// --- Trigger -------------------------------------------------------------

/// Declarative trigger attributes — Base UI's `render` prop in Gleam form.
/// Merge onto a `<button>` (or a styled `Button` / `<a>` from your design
/// system) to turn it into the tooltip trigger. The headless layer never renders
/// the element itself — the styled layer (or your app) does.
///
/// Uses [Interest Invokers](https://developer.mozilla.org/en-US/docs/Web/API/Popover_API/Using_interest_invokers):
/// `interestfor="<content-id>"` makes the browser show the hint on interest
/// (hover / focus / long-press) and hide it on loss of interest, with no JS.
/// `interestfor` is valid on `<a>`, `<button>` and `<area>`.
///
/// `delay` / `close_delay` are the open / close delays **in milliseconds**,
/// emitted as the native `interest-delay-start` / `interest-delay-end` CSS
/// properties (Base UI's `delay` / `closeDelay`). They sit inline alongside the
/// `anchor-name` so positioning and timing travel together as one `style`.
///
/// `aria-describedby` is emitted explicitly (pointing at the hint) for robust,
/// universal accessibility; it matches the association interest invokers wire
/// natively, so there's no double-describe.
pub fn trigger_attributes(
  anatomy: Anatomy,
  delay delay: Int,
  close_delay close_delay: Int,
) -> List(Attribute(msg)) {
  let Nil = ensure_interest_invokers_polyfill()
  [
    attribute.id(anatomy.anchor_id),
    attribute.attribute("interestfor", anatomy.content_id),
    attribute.attribute("aria-describedby", anatomy.content_id),
    // Mirror the native interest delays as plain-ms data-* so the Safari
    // polyfill can read them: browsers that lack Interest Invokers also drop the
    // unknown `interest-delay-*` CSS, so it never survives in the inline style.
    attribute.attribute("data-interest-delay-start", int.to_string(delay)),
    attribute.attribute("data-interest-delay-end", int.to_string(close_delay)),
    trigger_style(anatomy, delay, close_delay),
  ]
}

/// The trigger's load-bearing inline `style`: the `anchor-name` (so the hint can
/// tether to it) plus the native interest delays. One `style` attribute keeps
/// Lustre from emitting two and lets positioning + timing be set together.
fn trigger_style(
  anatomy: Anatomy,
  delay: Int,
  close_delay: Int,
) -> Attribute(msg) {
  attribute.styles([
    #("anchor-name", anchor_name(anatomy.anchor_id)),
    #("interest-delay-start", int.to_string(delay) <> "ms"),
    #("interest-delay-end", int.to_string(close_delay) <> "ms"),
  ])
}

// --- Popup (Positioner + Popup) ------------------------------------------

/// The floating hint. **Always rendered** in the DOM — the browser shows and
/// hides it via the top layer (`display: none` in the UA stylesheet when closed,
/// no layout/paint cost), so SSR round-trips the whole structure and CSS anchor
/// positioning has both anchor + hint laid out from the first frame (no flash on
/// first open). Carries `role="tooltip"`, `popover="hint"`, and `data-side` /
/// `data-align` styling hooks.
///
/// `placement` chooses side + alignment; `side_offset` is the anchor↔hint
/// spacing **in pixels** — a neutral unit the styled layer decides. It applies to
/// whichever side `placement` picks, so pass one number regardless of side.
pub fn popup(
  anatomy: Anatomy,
  placement: Placement,
  side_offset: Int,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.div(
    list.flatten([
      [
        attribute.id(anatomy.content_id),
        attribute.attribute("role", "tooltip"),
        attribute.attribute("popover", "hint"),
        attribute.attribute(
          "data-side",
          positioning.side_to_string(placement.side),
        ),
        attribute.attribute(
          "data-align",
          positioning.align_to_string(placement.align),
        ),
      ],
      positioning.positioned_style(anatomy.anchor_id, placement, side_offset),
      attrs,
    ]),
    children,
  )
}

// --- Arrow ---------------------------------------------------------------

/// Decorative arrow, anchored to the **trigger** (not to the hint) via the
/// shared `gg_base_ui/arrow/arrow` primitive. A thin wrapper that threads
/// `anatomy.anchor_id` through so tooltip callers don't have to. No placement
/// argument: the arrow reads the hint's resolved `data-side` from CSS, so it's
/// identical regardless of where the hint opens.
pub fn arrow(anatomy: Anatomy, attrs: List(Attribute(msg))) -> Element(msg) {
  arrow.arrow(anatomy.anchor_id, attrs)
}

// --- Interest Invokers polyfill install --------------------------------------

// Idempotent install of the Interest Invokers polyfill — a no-op where the
// native API exists (Chrome/Firefox) and on the BEAM. `trigger_attributes`
// calls it so the declarative `interestfor` hover/focus trigger still works on
// Safari (which has the Popover API but not Interest Invokers).
@external(javascript, "./tooltip_ffi.ts", "ensureInterestInvokersPolyfill")
fn ensure_interest_invokers_polyfill() -> Nil {
  Nil
}

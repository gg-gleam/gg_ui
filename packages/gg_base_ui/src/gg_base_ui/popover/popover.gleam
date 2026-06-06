//// Headless popover, native-first — a Lustre port of Base UI's `Popover.*`
//// anatomy.
////
//// Base UI exposes the popover as composable parts (`Root`, `Trigger`,
//// `Portal`, `Positioner`, `Popup`, `Arrow`, `Title`, `Description`, `Close`).
//// We mirror that surface, but lean on web platform primitives instead of a JS
//// runtime:
////
//// - **No Root state in the host model.** The native [Popover
////   API](https://developer.mozilla.org/en-US/docs/Web/API/Popover_API) makes
////   the browser the source of truth for `open`. `Anatomy` is just the set of
////   stable IDs each part needs; no `Bool` lives in Gleam-land.
//// - **Layering + dismissal** use `popover="auto"`: the browser puts the popup
////   in the **top layer** (escaping `overflow`/`transform` clipping — so Base
////   UI's `Portal` is unnecessary) and handles light-dismiss (outside-click +
////   Escape) for free.
//// - **Trigger + Close use [Invoker
////   Commands](https://developer.mozilla.org/en-US/docs/Web/API/Invoker_Commands_API)**
////   (`command="toggle-popover"` / `"hide-popover"` + `commandfor`). The browser
////   maintains `aria-expanded` on the invoker natively, so we need **no JS
////   observer** to mirror disclosure state. (The native API does *not* set
////   `aria-haspopup`, so we still emit that ourselves.)
//// - **Positioner + Popup** collapse onto one element positioned by
////   `gg_base_ui/positioning` (native CSS anchor positioning).
//// - **Title / Description / Close / Arrow** are thin element helpers carrying
////   the right ids, ARIA wiring, and `data-*` attributes for styling.
//// - **Visual open/closed styling** comes from the native `:popover-open` CSS
////   pseudo-class — no `data-open`/`data-closed` mirror to keep in sync.
////
//// Two *optional, orthogonal* capabilities layer on top of the plain
//// declarative popover — neither is required, and they compose freely:
////
//// - **observe** — pass `on_toggle: Some(f)` to `popup` to mirror the open
////   state into your model from the native `toggle` event (`f(True)` on open,
////   `f(False)` on close). `None` wires no handler at all.
//// - **command** — `open` / `close` / `toggle` return `Effect`s keyed by the
////   handle's content id, so you can drive *any* popover from `update`, an async
////   task, or an external (non-trigger) button. No host state required.
////
//// Deliberately out of scope for the native-first model: `Backdrop`, modal /
//// focus-trapping, `Viewport` transitions, `openOnHover`, and detached
//// `Handle`s / multiple triggers. They need a JS runtime we don't want here;
//// they can layer on later behind these same parts.

import gg_base_ui/arrow/arrow
import gg_base_ui/helpers/id_gen/id_gen
import gg_base_ui/positioning/positioning.{type Placement}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute.{type Attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

// --- Anatomy -------------------------------------------------------------

/// Stable IDs each part needs — the trigger's anchor id, the popup's content
/// id (referenced by `commandfor`), and the title/description ids that
/// `aria-labelledby` / `aria-describedby` point at, all derived from one base.
///
/// **Construct once and reuse** — generate in `init` and keep it in your model,
/// or once at the top of a render-once static view, then thread it through
/// `view`. Do **not** call `anatomy()` inside a re-rendering `view`: it mints a
/// fresh base each call (see `id_gen`), which would change the ids out from
/// under the `commandfor` link they wire.
pub type Anatomy {
  Anatomy(
    anchor_id: String,
    content_id: String,
    title_id: String,
    description_id: String,
  )
}

/// Build an `Anatomy` with a freshly-generated, collision-free base id — the
/// default. Callers never invent or expose an id, so two popovers on the same
/// page can't clash. The `useId` analogue (see `gg_base_ui/helpers/id_gen/id_gen`): call
/// **once** per popover and reuse the result; never recompute it per render.
pub fn anatomy() -> Anatomy {
  anatomy_with_id(id_gen.generate_with_prefix("popover"))
}

/// Build an `Anatomy` from an explicit, caller-chosen base id. Escape hatch for
/// when the id must be deterministic — tests, or pinning ids across a
/// server/client render boundary. Prefer `anatomy()` otherwise so ids stay an
/// internal detail. The caller is responsible for keeping `id` unique on the
/// page. Safe to call in `view` *and* `update` (it's a pure id derivation).
pub fn anatomy_with_id(id: String) -> Anatomy {
  Anatomy(
    anchor_id: id <> "-anchor",
    content_id: id <> "-content",
    title_id: id <> "-title",
    description_id: id <> "-description",
  )
}

// --- Dismiss -------------------------------------------------------------

/// Dismissal behavior, mapping to the native `popover` attribute value:
///
/// - `Auto`: light-dismiss — clicking outside the popup or pressing Escape
///   closes it. The default for menus / tooltips / standard popovers and what
///   you want 95% of the time.
/// - `Manual`: the host fully owns close. The popup stays open across outside
///   interaction (scrolling, clicking elsewhere, …) until explicitly closed
///   via the `close` effect, a `close` button (`command="hide-popover"`), or
///   Escape (the platform always honours Escape on `popover="manual"`).
///   Use for popups that need to persist while the user explores around them
///   — collision-test panels, side palettes, etc.
pub type Dismiss {
  Auto
  Manual
}

fn dismiss_to_string(dismiss: Dismiss) -> String {
  case dismiss {
    Auto -> "auto"
    Manual -> "manual"
  }
}

// --- Trigger -------------------------------------------------------------

/// Declarative trigger attributes — Base UI's `render` prop in Gleam form.
/// Merge onto a `<button>` (or a styled `Button` from your design system) to
/// turn it into the popover trigger; button-only because the native Invoker
/// Commands association requires a `<button>`. The headless layer never renders
/// the button itself — the styled layer (or your app) does.
///
/// Uses [Invoker Commands](https://developer.mozilla.org/en-US/docs/Web/API/Invoker_Commands_API):
/// `command="toggle-popover"` + `commandfor` toggles the popup open/closed and
/// — crucially — has the browser maintain `aria-expanded` on the trigger
/// natively, so no JS observer is needed. The `aria-expanded="false"` here is a
/// static SSR seed; the platform takes over live once hydrated. `aria-haspopup`
/// is *not* set by the native API, so we emit it ourselves.
pub fn trigger_attributes(anatomy: Anatomy) -> List(Attribute(msg)) {
  list.flatten([
    [
      attribute.id(anatomy.anchor_id),
      attribute.attribute("command", "toggle-popover"),
      attribute.attribute("commandfor", anatomy.content_id),
      positioning.anchor_style(anatomy.anchor_id),
    ],
    trigger_aria(),
  ])
}

fn trigger_aria() -> List(Attribute(msg)) {
  [
    attribute.attribute("aria-haspopup", "dialog"),
    attribute.attribute("aria-expanded", "false"),
  ]
}

// --- Popup (Positioner + Popup) ------------------------------------------

/// The floating content. **Always rendered** in the DOM — the browser shows
/// and hides it via the top layer (`display: none` in the UA stylesheet when
/// closed, no layout/paint cost). This differs from Base UI/Radix, which
/// conditionally mount the popup based on React state; we keep it mounted so
/// (a) SSR round-trips the whole structure, (b) CSS anchor positioning has
/// both anchor + popup laid out from the first frame (no flash on first
/// open), and (c) we don't need a JS state machine to manage mount/unmount.
///
/// `placement` chooses side + alignment; `side_offset` is the anchor↔popup
/// spacing **in pixels** — a neutral unit the styled layer decides (the headless
/// layer bakes in no number). It applies to whichever side `placement` picks, so
/// pass one number regardless of side.
///
/// `dismiss` decides whether the platform light-dismisses on outside click /
/// Escape (`Auto`) or the host fully owns close (`Manual`). Default to `Auto`
/// unless you have a specific reason — e.g. a panel that should survive scroll
/// or background interaction.
///
/// `on_toggle` is the **observe** capability: `Some(f)` wires the native
/// `toggle` event so the host mirrors open state into its model (`f(True)` on
/// open, `f(False)` on close); `None` wires no handler and keeps the popover
/// pure-declarative (browser owns visibility, CSS `:popover-open` owns visual
/// styling, the trigger maintains `aria-expanded` natively).
///
/// Carries `data-side` / `data-align` for styling hooks. Label/describe it by
/// including `labelled_by` / `described_by` in `attrs` alongside a `title` /
/// `description`.
pub fn popup(
  anatomy: Anatomy,
  placement: Placement,
  side_offset: Int,
  dismiss: Dismiss,
  on_toggle: Option(fn(Bool) -> msg),
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  let toggle_handler = case on_toggle {
    None -> []
    Some(on_change) -> [event.on("toggle", decode_toggle(on_change))]
  }
  html.div(
    list.flatten([
      [
        attribute.id(anatomy.content_id),
        attribute.attribute("role", "dialog"),
        attribute.attribute("popover", dismiss_to_string(dismiss)),
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
      toggle_handler,
      attrs,
    ]),
    children,
  )
}

fn decode_toggle(on_change: fn(Bool) -> msg) -> decode.Decoder(msg) {
  use new_state <- decode.field("newState", decode.string)
  decode.success(on_change(new_state == "open"))
}

/// Point a popup's `aria-labelledby` at its `title`. Add to `popup`'s attrs.
pub fn labelled_by(anatomy: Anatomy) -> Attribute(msg) {
  attribute.attribute("aria-labelledby", anatomy.title_id)
}

/// Point a popup's `aria-describedby` at its `description`. Add to `popup`'s
/// attrs.
pub fn described_by(anatomy: Anatomy) -> Attribute(msg) {
  attribute.attribute("aria-describedby", anatomy.description_id)
}

// --- Title / Description / Close / Arrow ---------------------------------

/// Accessible heading for the popup. Renders `<h2>` with the id `labelled_by`
/// references.
pub fn title(
  anatomy: Anatomy,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.h2([attribute.id(anatomy.title_id), ..attrs], children)
}

/// Supplementary text. Renders `<p>` with the id `described_by` references.
pub fn description(
  anatomy: Anatomy,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.p([attribute.id(anatomy.description_id), ..attrs], children)
}

/// Attributes for a close button that closes the popover natively via the
/// `command="hide-popover"` Invoker Command — no JS, works inside the
/// declarative flow. Merge onto a `<button>` (or a styled `Button` from your
/// design system).
pub fn close_attributes(anatomy: Anatomy) -> List(Attribute(msg)) {
  [
    attribute.attribute("command", "hide-popover"),
    attribute.attribute("commandfor", anatomy.content_id),
  ]
}

/// Decorative arrow, anchored to the **trigger** (not to the popup) via the
/// shared `gg_base_ui/arrow/arrow` primitive. This is a thin wrapper that
/// threads `anatomy.anchor_id` through so popover callers don't have to —
/// any non-popover caller (tooltip, menu, …) can use `arrow.arrow` directly.
/// No placement argument: the arrow reads the popup's resolved `data-side` from
/// CSS, so it's identical regardless of where the popup opens.
pub fn arrow(anatomy: Anatomy, attrs: List(Attribute(msg))) -> Element(msg) {
  arrow.arrow(anatomy.anchor_id, attrs)
}

// --- Command capability --------------------------------------------------
//
// Drive any popover imperatively, keyed by its content id. Works regardless of
// whether the host observes state — handy for opening from `update`, an async
// task, or an external (non-trigger) button. JS-only; the Erlang fallbacks
// never run because effects execute client-side.

@external(javascript, "./popover_ffi.ts", "showPopover")
fn show_popover(_content_id: String) -> Nil {
  Nil
}

@external(javascript, "./popover_ffi.ts", "hidePopover")
fn hide_popover(_content_id: String) -> Nil {
  Nil
}

@external(javascript, "./popover_ffi.ts", "togglePopover")
fn toggle_popover(_content_id: String) -> Nil {
  Nil
}

/// Open the popover. No-op if it's already open.
pub fn open(anatomy: Anatomy) -> Effect(msg) {
  effect.from(fn(_dispatch) { show_popover(anatomy.content_id) })
}

/// Close the popover. No-op if it's already closed.
pub fn close(anatomy: Anatomy) -> Effect(msg) {
  effect.from(fn(_dispatch) { hide_popover(anatomy.content_id) })
}

/// Toggle the popover's open state.
pub fn toggle(anatomy: Anatomy) -> Effect(msg) {
  effect.from(fn(_dispatch) { toggle_popover(anatomy.content_id) })
}

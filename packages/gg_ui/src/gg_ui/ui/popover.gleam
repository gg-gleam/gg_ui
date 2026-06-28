//// shadcn-flavoured popover — the **thin** styled layer built on the headless
//// `gg_base_ui/popover`. Mirrors shadcn's authoring model: this layer
//// emits *class names* (`cn-popover`, `cn-popover-positioner`, …) whose
//// Tailwind recipes live in the per-style CSS (`styles/nova.css`, scoped under
//// `.style-nova`). This is the layer a future CLI copies into a consuming app.
////
//// Mirrors shadcn's parts: `trigger` (an outline `Button`), `content`
//// (`PopoverContent` — the positioned, labelled box), `header`, `title`,
//// `description`, `close`, and an optional `arrow`. For the common case there's
//// also a terse `popover` that hides the anatomy/positioner/aria plumbing and
//// only asks for the trigger + content children (shadcn's `<Popover>` feel).
////
//// **`gg_base_ui` is a true internal dependency — it never appears in this
//// module's public API.** Consumers name only gg_ui types: `Anatomy` (a thin
//// re-export of the headless handle, which you never construct directly),
//// `Dismiss` (gg_ui's own enum, mapped to the headless one internally), and
//// `gg_ui/positioning`'s `Side` / `Align`. The `anatomy` / `show` / `hide` /
//// `toggle` wrappers re-expose the headless capabilities under gg_ui's name.
//// This keeps the styled surface stable even if the headless layer is
//// restructured — and matches how `button` owns its own `Variant` / `Size`.
////
//// Per rule 8, the visible card emits its overridable structural utility (`w-72`)
//// raw and folds a caller's `class` (in `content`'s `attrs`) via `cn.merge`, so a
//// width override (`w-80`) wins; the themeable surface stays in the `cn-*` recipe.
//// `header` / `title` / `description` likewise take `attrs` for additive classes.
////
//// Native-first behavior is preserved verbatim: the two-box anatomy and the
//// native `:popover-open` visual state are *behavior*, not looks — they stay
//// here, not in the CSS. The arrow's per-side geometry and trigger-ward offset
//// are pure visuals: they live in `styles/shapes/arrow.css` (keyed on the
//// popup's `data-side`), with the offset value exposed as the `--arrow-offset`
//// custom property on `cn-popover-arrow-icon`.
////
//// Every trigger/close composes the headless behavior attributes onto our
//// design-system `Button` — Base UI's `render` prop, in Gleam form. The
//// headless layer never renders a `<button>` itself; this layer always does.

import gg_base_ui/helpers/cn
import gg_base_ui/popover/popover as base_popover
import gg_ui/positioning.{type Align, type Side, Bottom, End}
import gg_ui/ui/button
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

// --- Anatomy + capabilities (facade over the headless handle) ------------
//
// gg_base_ui stays internal: callers obtain an `Anatomy` from `anatomy` /
// `anatomy_with_id` (or the terse `popover`'s children callback) and drive the
// popover with the `show` / `hide` / `toggle` effects — all named under gg_ui.

/// The popover handle: the stable set of ids the parts share (anchor, content,
/// title, description). A re-export of the headless type — you never construct
/// it directly; you get one from `anatomy` / `anatomy_with_id` or the terse
/// `popover` children callback, then thread it through `trigger` / `content` /
/// `title` / `description` / `close`.
pub type Anatomy =
  base_popover.Anatomy

/// Build an `Anatomy` with a freshly-generated, collision-free id — the
/// default. Call **once** per popover and reuse the result (the `useId`
/// analogue); never recompute it per render, or the ids wiring the parts would
/// change out from under each other.
pub fn anatomy() -> Anatomy {
  base_popover.anatomy()
}

/// Build an `Anatomy` from an explicit, caller-chosen base id. Escape hatch for
/// when the id must be deterministic (tests, or pinning across a server/client
/// render boundary). Prefer `anatomy` otherwise; the caller owns uniqueness.
/// Safe to call in both `view` and `update` (it's a pure id derivation).
pub fn anatomy_with_id(id: String) -> Anatomy {
  base_popover.anatomy_with_id(id)
}

/// Dismissal behavior. `Auto` light-dismisses (outside click + Escape) — the
/// 95% default; `Manual` keeps the host in full control of close (the popup
/// survives outside interaction until closed via the `hide` effect, a `close`
/// button, or Escape). Mapped to the headless `Dismiss` internally.
pub type Dismiss {
  Auto
  Manual
}

fn dismiss_to_base(dismiss: Dismiss) -> base_popover.Dismiss {
  case dismiss {
    Auto -> base_popover.Auto
    Manual -> base_popover.Manual
  }
}

/// Show the popover imperatively (the **command** capability), keyed by the
/// handle. No-op if already open. Drive it from `update`, an async task, or an
/// external (non-trigger) button — no host state required. (Named after the
/// native `showPopover`; distinct from the `close` *button* part below.)
pub fn show(anatomy: Anatomy) -> Effect(msg) {
  base_popover.open(anatomy)
}

/// Hide the popover imperatively. No-op if already closed. (Native
/// `hidePopover`.)
pub fn hide(anatomy: Anatomy) -> Effect(msg) {
  base_popover.close(anatomy)
}

/// Toggle the popover's open state imperatively. (Native `togglePopover`.)
pub fn toggle(anatomy: Anatomy) -> Effect(msg) {
  base_popover.toggle(anatomy)
}

// --- Parts ---------------------------------------------------------------

/// shadcn's `<PopoverTrigger render={<Button variant="outline" />}>`: the
/// trigger's *behavior* merged onto a `Button` that owns the *appearance*. You
/// pass the `variant` / `size` (shadcn defaults the trigger to outline/medium —
/// pass `button.Outline` / `button.Medium` for that look); the `Button`
/// requires both, so there's no hidden lock-in. The native Invoker Command
/// (`command="toggle-popover"`) toggles open/close and maintains
/// `aria-expanded` natively — no host state.
pub fn trigger(
  anatomy: Anatomy,
  variant variant: button.Variant,
  size size: button.Size,
  attrs attrs: List(attribute.Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  // User attrs first, behaviour attrs last so the Invoker Command + anchor + aria
  // wiring always wins a conflict; a caller `class` is merged by `button` itself.
  button.button(
    variant:,
    size:,
    attrs: list.append(attrs, base_popover.trigger_attributes(anatomy)),
    children:,
  )
}

/// The trigger's headless behaviour attributes (Invoker Command + anchor +
/// aria) to merge onto **your own** element — Base UI's `render` prop in Gleam
/// form. Reach for this only when you don't want the styled `Button`:
/// `html.button([..popover.trigger_attributes(pop)], [html.text("Open")])`.
/// For the common styled trigger, use `trigger` (it carries these attributes
/// for you).
pub fn trigger_attributes(anatomy: Anatomy) -> List(attribute.Attribute(msg)) {
  base_popover.trigger_attributes(anatomy)
}

// --- Terse API -----------------------------------------------------------
//
// The composable parts above mirror Base UI: you mint an `Anatomy` and thread
// it through `trigger`/`content`/`title`/… yourself, for full control. The
// terse `popover` below is the shadcn-`<Popover>`-style convenience for the
// common case — it hides the mechanics (anatomy generation, the positioner/card
// box, aria) so the call site only decides the trigger and the content
// children. Both are anatomy callbacks: `popover` mints the `Anatomy` and hands
// it to each, so you build the trigger with the very same `trigger` (or
// `trigger_attributes` for a custom element) you'd use standalone — no separate
// trigger type. Reach for the parts when you need anything the slots don't cover.

/// Everything the terse `popover` lets you tune, with sensible defaults from
/// `options`. Pass `options: popover.options()` for the common case, or
/// override **only** what you need with Gleam's record-update syntax:
///
/// ```gleam
/// popover.options()                                  // all defaults
/// Options(..popover.options(), text: "Open Popover") // just the trigger label
/// Options(..popover.options(), side: Top, arrow: True)
/// ```
///
/// **Trigger** (used by `popover`; ignored by `popover_with_trigger`, where you
/// bring your own element):
/// - `text`: the trigger button's label.
/// - `variant` / `size`: the trigger button's look (the `Button` enums).
///
/// **Popup**:
/// - `id`: `None` auto-generates a collision-free id (the default); `Some(id)`
///   pins it (tests, server/client render boundaries) — you own uniqueness.
/// - `side` / `align`: where the popup opens relative to the trigger, set
///   independently (no combined value).
/// - `arrow`: render the decorative tail.
/// - `on_toggle`: the **observe** capability — `Some(f)` mirrors the native
///   toggle state into your model; `None` keeps it pure-declarative.
/// - `dismiss`: `Auto` light-dismiss vs `Manual` host-owned close.
pub type Options(msg) {
  Options(
    id: Option(String),
    text: String,
    variant: button.Variant,
    size: button.Size,
    side: Side,
    align: Align,
    arrow: Bool,
    on_toggle: Option(fn(Bool) -> msg),
    dismiss: Dismiss,
  )
}

/// The terse popover's defaults: an outline/medium trigger labelled `"Open"`, an
/// auto-generated id, opening **bottom / end** (below the trigger, right-
/// aligned), no arrow, no observe callback, and light-dismiss (`Auto`). Spread
/// it with record-update to change a field — `Options(..popover.options(),
/// text: "Open Popover")`.
pub fn options() -> Options(msg) {
  Options(
    id: None,
    text: "Open",
    variant: button.Outline,
    size: button.Medium,
    side: Bottom,
    align: End,
    arrow: False,
    on_toggle: None,
    dismiss: Auto,
  )
}

/// Terse popover — the whole disclosure in one call, mechanics hidden. The
/// shadcn `<Popover>` equivalent.
///
/// The trigger is the styled button described by `options` (`text` / `variant`
/// / `size`); `children` is a callback that receives the minted `Anatomy` so you
/// compose `title` / `description` (which need the shared ids) and any normal
/// Lustre children. Pass `popover.options()` for all-defaults, or spread it to
/// override only what you need — e.g. `Options(..popover.options(), text:
/// "Open Popover")`. Nothing is forced.
///
/// Want a trigger that *isn't* the styled button (an icon button, a link, a
/// custom element)? Use `popover_with_trigger` and pass your own. For full
/// structural control everywhere, drop to the composable parts.
///
/// Render-once by design (the native popover lets the browser own open state).
/// In a re-rendering app that observes/commands the popover, use the parts with
/// an explicit `anatomy_with_id` kept stable across renders instead.
pub fn popover(
  options options: Options(msg),
  children children: fn(Anatomy) -> List(Element(msg)),
) -> Element(msg) {
  popover_with_trigger(
    trigger: fn(anatomy) {
      trigger(
        anatomy,
        variant: options.variant,
        size: options.size,
        attrs: [],
        children: [html.text(options.text)],
      )
    },
    options:,
    children:,
  )
}

/// Terse popover with a **caller-supplied trigger** — same as `popover` but you
/// provide the trigger element via a callback that receives the minted
/// `Anatomy`. Build it with the standalone `trigger` (full button props) or your
/// own element via `trigger_attributes` (`html.button([..trigger_attributes(pop)],
/// …)`). The `text` / `variant` / `size` fields of `options` don't apply here —
/// your trigger owns its own appearance; the rest of `options` (placement,
/// arrow, dismiss, observe, id) still does.
pub fn popover_with_trigger(
  trigger trigger: fn(Anatomy) -> Element(msg),
  options options: Options(msg),
  children children: fn(Anatomy) -> List(Element(msg)),
) -> Element(msg) {
  let Options(id:, side:, align:, arrow:, on_toggle:, dismiss:, ..) = options
  let anatomy = case id {
    Some(id) -> anatomy_with_id(id)
    None -> anatomy()
  }
  element.fragment([
    trigger(anatomy),
    content(
      anatomy,
      side:,
      align:,
      dismiss:,
      arrow:,
      on_toggle:,
      attrs: [],
      children: children(anatomy),
    ),
  ])
}

/// `PopoverContent`: the positioned, labelled popup box. The full-control part —
/// `side` / `align` pick where it opens (set independently), and `dismiss` is
/// explicit (`Auto` light-dismiss vs `Manual` host-owned close). `on_toggle` is
/// the optional **observe** capability — `Some(f)` mirrors the native toggle
/// state into the host model, `None` keeps it pure-declarative. Set
/// `arrow: True` for the decorative tail.
///
/// Two-box anatomy: the positioned element (the popover) is a **transparent
/// container** (`cn-popover-positioner`) — it resets the UA `[popover]`
/// border/padding/background and only keeps positioning + `overflow-visible`.
/// The visible card (`cn-popover` — border, radius, padding, shadow,
/// background) is an **inner wrapper**. That split lets the arrow's SVG sit in
/// front of the card (`z-10`) and overlap its top border without clipping — its
/// fill covers the card's border line in the arrow's width, producing a
/// continuous tail instead of a closed triangle stamped on top of the card edge
/// (see `arrow_element`).
///
/// Visual styling is driven by the native `:popover-open` CSS pseudo-class —
/// no `data-open`/`data-closed` mirror needed. Wires
/// `aria-labelledby`/`aria-describedby` (resolved by id across the wrapper), so
/// include a `title` (and usually a `description`) among the children.
pub fn content(
  anatomy: Anatomy,
  side side: Side,
  align align: Align,
  dismiss dismiss: Dismiss,
  arrow arrow: Bool,
  on_toggle on_toggle: Option(fn(Bool) -> msg),
  attrs attrs: List(attribute.Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  // `attrs` land on the visible card (shadcn's `PopoverContent className`); the
  // card's `w-72` is raw so a width override (`w-80`) wins via cn.merge.
  let card = html.div(cn.merge(own: "cn-popover w-72", attrs:), children)
  // Render one arrow at the requested side. When the popup flips on viewport
  // collision (`position-try-fallbacks`), the JS observer installed by
  // `arrow.arrow` rewrites this single SVG's geometry + positioning to match
  // the resolved side — no need to pre-render the other three.
  let kids = case arrow {
    True -> [card, arrow_element(anatomy)]
    False -> [card]
  }
  base_popover.popup(
    anatomy,
    positioning.to_base(side, align),
    // nova's anchor↔popup gap, in px. The shape layer owns this number.
    8,
    dismiss_to_base(dismiss),
    on_toggle,
    [
      attribute.class("cn-popover-positioner"),
      base_popover.labelled_by(anatomy),
      base_popover.described_by(anatomy),
    ],
    kids,
  )
}

/// `PopoverHeader`: stacks a title and description with tight spacing.
pub fn header(
  attrs attrs: List(attribute.Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  html.div(cn.merge(own: "cn-popover-header", attrs:), children)
}

/// `PopoverTitle`: the accessible heading the content is labelled by.
pub fn title(
  anatomy: Anatomy,
  attrs attrs: List(attribute.Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  base_popover.title(
    anatomy,
    cn.merge(own: "cn-popover-title", attrs:),
    children,
  )
}

/// `PopoverDescription`: muted supplementary text the content is described by.
pub fn description(
  anatomy: Anatomy,
  attrs attrs: List(attribute.Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  base_popover.description(
    anatomy,
    cn.merge(own: "cn-popover-description", attrs:),
    children,
  )
}

/// `PopoverClose`: a ghost `Button` that closes the popover natively via the
/// `command="hide-popover"` Invoker Command — no JS, works inside the
/// declarative flow.
pub fn close(
  anatomy: Anatomy,
  attrs attrs: List(attribute.Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  button.button(
    variant: button.Ghost,
    size: button.Sm,
    attrs: list.append(attrs, base_popover.close_attributes(anatomy)),
    children:,
  )
}

/// The decorative arrow (Base UI's `Popover.Arrow`): an SVG triangle anchored
/// to the trigger via the shared `arrow` primitive. Sits **in front of** the
/// card (`z-10`, via `cn-popover-arrow-icon`) so the polygon's fill paints over
/// the card's top border in the arrow's width region — the popup's outline
/// appears to "lift up" into the arrow shape instead of drawing a flat line
/// across its base.
///
/// The 2px logical offset overlaps the polygon's base 1px past the popup
/// edge, so the polygon's fill fully covers the card's border line at the
/// seam (`gap_px - arrow_size + overlap_px` = `8 - 7 + 1 = 2`). Margin
/// direction matches the trigger-facing side. These offset styles are
/// *behavior* (geometry the flip observer re-applies), so they stay inline
/// rather than moving to the CSS recipe.
///
/// Only **one** arrow is rendered. Its side, size, placement, and offset are
/// all CSS keyed on the popup's resolved `data-side` (`styles/shapes/arrow.css`),
/// so when the popup flips on viewport collision (`position-try-fallbacks`) the
/// observer only flips that one attribute and CSS swaps everything else — a
/// single SVG node follows the popup through any flip with no per-element
/// rewriting. The trigger-ward overlap is the `--arrow-offset` custom property
/// (set on `.cn-popover-arrow-icon`, see the shape recipe); the shared fragment
/// applies it on whichever side is trigger-facing.
fn arrow_element(anatomy: Anatomy) -> Element(msg) {
  base_popover.arrow(anatomy, [attribute.class("cn-popover-arrow-icon")])
}

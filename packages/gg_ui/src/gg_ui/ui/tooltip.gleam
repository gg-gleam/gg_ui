//// shadcn-flavoured tooltip — the **thin** styled layer built on the headless
//// `gg_base_ui/tooltip`. Mirrors shadcn's authoring model: this layer emits
//// *class names* (`cn-tooltip`, `cn-tooltip-positioner`, …) whose Tailwind
//// recipes live in the per-style CSS (`styles/shapes/<style>/tooltip.css`,
//// scoped under `.style-<name>`). This is the layer a future CLI copies into a
//// consuming app.
////
//// Mirrors shadcn's parts — `Tooltip`, `TooltipTrigger`, `TooltipContent`
//// (`TooltipProvider` is unnecessary: the shared delay window is the only thing
//// it adds, and that's the JS-runtime extra we deliberately skip). For the common
//// case there's a terse `tooltip` that hides the anatomy/positioner/aria plumbing
//// and only asks for a trigger label + the tip content (shadcn's `<Tooltip>` feel).
////
//// **`gg_base_ui` is a true internal dependency — it never appears in this
//// module's public API.** Consumers name only gg_ui types: `Anatomy` (a thin
//// re-export of the headless handle, which you never construct directly) and
//// `gg_ui/positioning`'s `Side` / `Align`. The `anatomy` wrapper re-exposes the
//// headless capability under gg_ui's name. This matches how `popover` and
//// `button` keep the headless layer behind the styled surface.
////
//// Native-first behavior is preserved verbatim: opening on **interest** (hover /
//// focus / long-press) via the Interest Invoker API, the native `popover="hint"`
//// top layer, native `interest-delay-*` timing, and the `:popover-open` visual
//// state are *behavior*, not looks — they stay in `gg_base_ui`, not the CSS. Only
//// pure-visual utilities move to `cn-*` class names.

import gg_base_ui/tooltip/tooltip as base_tooltip
import gg_ui/positioning.{type Align, type Side, Center, Top}
import gg_ui/ui/button
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

// --- Anatomy (facade over the headless handle) ---------------------------

/// The tooltip handle: the stable ids the parts share (anchor + content). A
/// re-export of the headless type — you never construct it directly; you get one
/// from `anatomy` / `anatomy_with_id` or the terse `tooltip` children, then
/// thread it through `trigger` / `content`.
pub type Anatomy =
  base_tooltip.Anatomy

/// Build an `Anatomy` with a freshly-generated, collision-free id — the default.
/// Call **once** per tooltip and reuse the result (the `useId` analogue); never
/// recompute it per render, or the ids wiring the parts would change out from
/// under each other.
pub fn anatomy() -> Anatomy {
  base_tooltip.anatomy()
}

/// Build an `Anatomy` from an explicit, caller-chosen base id. Escape hatch for
/// when the id must be deterministic (tests, or pinning across a server/client
/// render boundary). Prefer `anatomy` otherwise; the caller owns uniqueness.
pub fn anatomy_with_id(id: String) -> Anatomy {
  base_tooltip.anatomy_with_id(id)
}

// --- Defaults ------------------------------------------------------------

/// Default open delay, **in milliseconds**, before the tooltip shows on hover /
/// focus. `0` mirrors shadcn's `TooltipProvider` default (`delayDuration={0}`):
/// the hint reveals as soon as you reach the trigger, the snappy feel the shadcn
/// docs have. (Base UI's calmer default is 600ms — pass that via `Options.delay`
/// / `trigger` if you'd rather the hint wait out a deliberate hover.)
pub const default_delay = 0

/// Default close delay, in milliseconds, before the tooltip hides after interest
/// is lost. `0` matches both shadcn and Base UI — the hint dismisses promptly.
pub const default_close_delay = 0

// --- Parts ---------------------------------------------------------------

/// shadcn's `<TooltipTrigger render={<Button />}>`: the trigger's *behavior*
/// (Interest Invoker wiring + anchor + delays + aria) merged onto a `Button`
/// that owns the *appearance*. You pass the `variant` / `size`; the `Button`
/// requires both, so there's no hidden lock-in. `delay` / `close_delay` are the
/// native open / close delays in ms — pass `default_delay` / `default_close_delay`
/// for the standard feel.
///
/// `attrs` are your own attributes/events on the styled button — an
/// `event.on_click`, a native `onclick`, an `id`, extra classes. They're applied
/// **before** the trigger's behavior attributes, so the load-bearing wiring (the
/// anchor-name `style`, the anchor `id`, `interestfor` / `aria-describedby`)
/// always wins a conflict and the tooltip can't be broken from the outside. Pass
/// `[]` when the trigger is purely presentational.
pub fn trigger(
  anatomy: Anatomy,
  variant variant: button.Variant,
  size size: button.Size,
  delay delay: Int,
  close_delay close_delay: Int,
  attrs attrs: List(attribute.Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  button.button(
    variant:,
    size:,
    attrs: list.append(
      attrs,
      base_tooltip.trigger_attributes(anatomy, delay:, close_delay:),
    ),
    children:,
  )
}

/// The trigger's headless behaviour attributes (Interest Invoker + anchor +
/// delays + aria) to merge onto **your own** element — Base UI's `render` prop in
/// Gleam form. Reach for this when you don't want the styled `Button` (an icon
/// button, an `<a>`, a custom element):
/// `html.button([..tooltip.trigger_attributes(tip, delay: 600, close_delay: 0)],
/// [html.text("?")])`. For the common styled trigger, use `trigger`.
pub fn trigger_attributes(
  anatomy: Anatomy,
  delay delay: Int,
  close_delay close_delay: Int,
) -> List(attribute.Attribute(msg)) {
  base_tooltip.trigger_attributes(anatomy, delay:, close_delay:)
}

/// `TooltipContent`: the positioned hint box. The full-control part — `side` /
/// `align` pick where it opens (set independently), and `arrow: True` adds the
/// decorative tail.
///
/// Two-box anatomy (shared with popover): the positioned element (the hint) is a
/// **transparent container** (`cn-tooltip-positioner`) that resets the UA
/// `[popover]` border/padding/background and keeps only positioning +
/// `overflow-visible`; the visible dark pill (`cn-tooltip` — `bg-foreground` /
/// padding / radius) is an **inner wrapper**. That split lets the arrow's SVG sit
/// in front of the pill and merge into it cleanly, and lets motion fade the
/// container while the pill zooms.
///
/// `side_offset` is the anchor↔hint gap: a snug 4px without an arrow (Base UI's
/// `sideOffset` default), widened to 10px with one. The wider gap pairs with a
/// larger `--arrow-offset` (5px) so the caret reads like shadcn's: a small
/// pointer sitting clearly off the trigger, not a big caret glued to it. The
/// caret is anchored to the trigger at a fixed 7px length, so the extra offset
/// both opens the tip↔trigger gap *and* buries more of the caret base into the
/// pill — shrinking the *visible* caret to ~5px while keeping it joined to the
/// pill.
pub fn content(
  anatomy: Anatomy,
  side side: Side,
  align align: Align,
  arrow arrow: Bool,
  children children: List(Element(msg)),
) -> Element(msg) {
  let pill = html.div([attribute.class("cn-tooltip")], children)
  let kids = case arrow {
    True -> [pill, arrow_element(anatomy)]
    False -> [pill]
  }
  let side_offset = case arrow {
    True -> 10
    False -> 4
  }
  base_tooltip.popup(
    anatomy,
    positioning.to_base(side, align),
    side_offset,
    [attribute.class("cn-tooltip-positioner")],
    kids,
  )
}

/// The decorative arrow (Base UI's `Tooltip.Arrow`): an SVG caret anchored to the
/// trigger via the shared `arrow` primitive, skinned to the hint's solid colour
/// (`fill-foreground`). Its side, size, placement, and offset are all CSS keyed
/// on the hint's resolved `data-side` (`styles/shapes/arrow.css`), so when the
/// hint flips on viewport collision the observer flips that one attribute and CSS
/// swaps everything else.
fn arrow_element(anatomy: Anatomy) -> Element(msg) {
  base_tooltip.arrow(anatomy, [attribute.class("cn-tooltip-arrow-icon")])
}

// --- Terse API -----------------------------------------------------------
//
// The composable parts above mirror Base UI: you mint an `Anatomy` and thread it
// through `trigger`/`content` yourself. The terse `tooltip` below is the
// shadcn-`<Tooltip>`-style convenience for the common case — it hides the
// mechanics (anatomy generation, the positioner box) so the call site only
// decides the trigger and the tip content.

/// Everything the terse `tooltip` lets you tune, with sensible defaults from
/// `options`. Pass `options: tooltip.options()` for the common case, or override
/// **only** what you need with Gleam's record-update syntax:
///
/// ```gleam
/// tooltip.options()                                    // all defaults
/// Options(..tooltip.options(), side: Bottom, arrow: True)
/// Options(..tooltip.options(), trigger_attrs: [event.on_click(Saved)])
/// ```
///
/// **Trigger** (used by `tooltip`; ignored by `tooltip_with_trigger`, where you
/// bring your own element):
/// - `variant` / `size`: the trigger button's look (the `Button` enums).
/// - `trigger_attrs`: your own attributes/events on the trigger button — an
///   `event.on_click`, a native `onclick`, an `id`, extra classes — without
///   dropping to `tooltip_with_trigger`. Same merge rule as the standalone
///   `trigger`: applied before the behavior wiring, which still wins a conflict.
///
/// **Hint**:
/// - `id`: `None` auto-generates a collision-free id (the default); `Some(id)`
///   pins it (tests, server/client render boundaries) — you own uniqueness.
/// - `side` / `align`: where the hint opens relative to the trigger, set
///   independently. Defaults to top/center, the conventional tooltip placement.
/// - `arrow`: render the decorative tail.
/// - `delay` / `close_delay`: native open / close delays, in ms.
pub type Options(msg) {
  Options(
    id: Option(String),
    variant: button.Variant,
    size: button.Size,
    trigger_attrs: List(attribute.Attribute(msg)),
    side: Side,
    align: Align,
    arrow: Bool,
    delay: Int,
    close_delay: Int,
  )
}

/// The terse tooltip's defaults: an outline/medium trigger, an auto-generated id,
/// opening **top / center** (the conventional placement), no arrow, and Base
/// UI's 600ms / 0ms delays. Spread it with record-update to change a field —
/// `Options(..tooltip.options(), side: Bottom)`.
pub fn options() -> Options(msg) {
  Options(
    id: None,
    variant: button.Outline,
    size: button.Medium,
    trigger_attrs: [],
    side: Top,
    align: Center,
    arrow: False,
    delay: default_delay,
    close_delay: default_close_delay,
  )
}

/// Terse tooltip — the whole thing in one call, mechanics hidden. The shadcn
/// `<Tooltip>` equivalent.
///
/// The trigger is the styled button described by `options` (`variant` / `size`);
/// `label` is its **content** — any elements, so it's `[html.text("Save")]` for a
/// text button, an icon, or both (e.g. an icon + a `sr-only` span to keep an
/// icon-only button named). `content` is the tip itself. Pass `tooltip.options()`
/// for all-defaults, or spread it to override only what you need — e.g.
/// `Options(..tooltip.options(), side: Bottom)`.
///
/// Want a trigger that *isn't* the styled button at all (a link, a bare element)?
/// Use `tooltip_with_trigger` and pass your own.
///
/// Render-once by design (the browser owns open state via interest).
pub fn tooltip(
  label label: List(Element(msg)),
  options options: Options(msg),
  content content: List(Element(msg)),
) -> Element(msg) {
  tooltip_with_trigger(
    trigger: fn(anatomy) {
      trigger(
        anatomy,
        variant: options.variant,
        size: options.size,
        delay: options.delay,
        close_delay: options.close_delay,
        attrs: options.trigger_attrs,
        children: label,
      )
    },
    options:,
    content:,
  )
}

/// Terse tooltip with a **caller-supplied trigger** — same as `tooltip` but you
/// provide the trigger element via a callback that receives the minted `Anatomy`.
/// Build it with the standalone `trigger` (full button props) or your own element
/// via `trigger_attributes`. The `variant` / `size` / `trigger_attrs` fields of
/// `options` don't apply here — your trigger owns its appearance and attributes;
/// the rest of `options` (placement, arrow, delays, id) still does.
pub fn tooltip_with_trigger(
  trigger trigger: fn(Anatomy) -> Element(msg),
  options options: Options(msg),
  content tip: List(Element(msg)),
) -> Element(msg) {
  let Options(id:, side:, align:, arrow:, ..) = options
  let anatomy = case id {
    Some(id) -> anatomy_with_id(id)
    None -> anatomy()
  }
  element.fragment([
    trigger(anatomy),
    content(anatomy, side:, align:, arrow:, children: tip),
  ])
}

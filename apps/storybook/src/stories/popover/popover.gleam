import gg_ui/positioning.{
  type Align, type Side, Bottom, Center, End, Left, Right, Start, Top,
}
import gg_ui/ui/button
import gg_ui/ui/popover
import gleam/option.{None, Some}
import helpers/scroll_canvas
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import stories/icons/demo_icons.{type DemoIcon, type IconSet, type IconVariant}

// --- uncontrolled mounts -------------------------------------------------
//
// No model, no msg, no update — the browser owns open/closed via the native
// Popover API. `lustre.element` is the right tool: a static view rendered
// once, no event loop in Gleam-land.

pub fn mount_basic(
  selector: String,
  side: String,
  align: String,
  arrow: Bool,
  variant: String,
  size: String,
  icon_set: String,
  icon_variant: String,
) -> Nil {
  mount_static(
    selector,
    view_basic(
      parse_side(side),
      parse_align(align),
      arrow,
      parse_variant(variant),
      parse_size(size),
      demo_icons.parse_set(icon_set),
      demo_icons.parse_variant(icon_variant),
    ),
  )
}

/// The scroll-collision app holds no state; its only message opens the popup
/// once the trigger has been centered (see `mount_scroll_collision`).
type ScrollMsg {
  Centered
}

pub fn mount_scroll_collision(
  selector: String,
  side: String,
  align: String,
  arrow: Bool,
  icon_set: String,
  icon_variant: String,
) -> Nil {
  let side = parse_side(side)
  let align = parse_align(align)
  let set = demo_icons.parse_set(icon_set)
  let icon_variant = demo_icons.parse_variant(icon_variant)
  // Mint the anatomy once (the `useId` call-once rule) and keep it stable across
  // the app. Unlike the other uncontrolled mounts, this one is a
  // `lustre.application` so `init` can center the trigger and then open the popup
  // so the collision demo renders ready to scroll around.
  //
  // Opening is sequenced *after* centering (the `Centered` message), not in
  // parallel: `show` → `showPopover` needs the popup in the DOM, and opening
  // before the centering scroll would resolve the popup's side against the
  // off-screen, un-centered trigger (flash + wrong `data-side`).
  let pop = popover.anatomy()
  let app =
    lustre.application(
      fn(_) { #(Nil, scroll_canvas.center_effect(pop.anchor_id, Centered)) },
      fn(model, msg) {
        case msg {
          Centered -> #(model, popover.show(pop))
        }
      },
      fn(_model) {
        view_scroll_collision(pop, side, align, arrow, set, icon_variant)
      },
    )
  let assert Ok(_) = lustre.start(app, selector, Nil)
  Nil
}

fn mount_static(selector: String, view: Element(Nil)) -> Nil {
  let app = lustre.element(view)
  let assert Ok(_) = lustre.start(app, selector, Nil)
  Nil
}

// --- imperative mount ----------------------------------------------------

pub fn mount_imperative(
  selector: String,
  side: String,
  align: String,
  icon_set: String,
  icon_variant: String,
) -> Nil {
  let side = parse_side(side)
  let align = parse_align(align)
  let set = demo_icons.parse_set(icon_set)
  let icon_variant = demo_icons.parse_variant(icon_variant)
  let app =
    lustre.application(
      // No anatomy in the model: the ids are deterministic
      // (`anatomy_with_id`), so `update` and `view` each rebuild the same
      // handle on demand. The model holds only the mirrored open flag, fed by
      // the native `toggle` event via the `on_toggle` observe capability.
      fn(_) { #(ImperativeModel(open: False), effect.none()) },
      update_imperative,
      fn(model) { view_imperative(model, side, align, set, icon_variant) },
    )
  let assert Ok(_) = lustre.start(app, selector, Nil)
  Nil
}

// --- imperative state ----------------------------------------------------

/// Deterministic id for the imperative story's popover. Rebuilt — never stored
/// — into the same `Anatomy` from both `view` and `update`.
const imperative_id = "popover-imperative"

type ImperativeModel {
  ImperativeModel(open: Bool)
}

type ImperativeMsg {
  /// Mirrored from the native `toggle` event (the **observe** capability) so
  /// the "currently open" label can track real browser state.
  PopoverOpenChanged(Bool)
  /// The three **command** capabilities, driven from external (non-trigger)
  /// buttons: `popover.show`, `popover.hide`, `popover.toggle`.
  ExternalOpenClicked
  ExternalCloseClicked
  ExternalToggleClicked
}

fn update_imperative(
  model: ImperativeModel,
  msg: ImperativeMsg,
) -> #(ImperativeModel, Effect(ImperativeMsg)) {
  let pop = popover.anatomy_with_id(imperative_id)
  case msg {
    // Observe-only: the browser already changed visibility, so just mirror it.
    PopoverOpenChanged(open) -> #(ImperativeModel(open:), effect.none())
    // Command: ask the browser to open/close/toggle; the `toggle` event (and
    // thus `PopoverOpenChanged`) follows and updates the label.
    ExternalOpenClicked -> #(model, popover.show(pop))
    ExternalCloseClicked -> #(model, popover.hide(pop))
    ExternalToggleClicked -> #(model, popover.toggle(pop))
  }
}

// --- args ----------------------------------------------------------------

/// Map the raw Storybook control strings to `Side` / `Align`. Unknown values
/// fall back to the component's default (`Bottom`/`Center`) so a stray arg can
/// never crash the story.
fn parse_side(side: String) -> Side {
  case side {
    "top" -> Top
    "right" -> Right
    "left" -> Left
    _ -> Bottom
  }
}

fn parse_align(align: String) -> Align {
  case align {
    "start" -> Start
    "end" -> End
    _ -> Center
  }
}

/// Map the raw Storybook control strings to the styled `Button`'s enums (shared
/// vocabulary in `stories/shared/button-controls.ts`). Safe fallback — `default`
/// and any stray value land on `Default` / `Medium` so a control can't crash.
fn parse_variant(variant: String) -> button.Variant {
  case variant {
    "destructive" -> button.Destructive
    "outline" -> button.Outline
    "secondary" -> button.Secondary
    "ghost" -> button.Ghost
    "link" -> button.Link
    _ -> button.Default
  }
}

fn parse_size(size: String) -> button.Size {
  case size {
    "xs" -> button.Xs
    "sm" -> button.Sm
    "lg" -> button.Lg
    "icon" -> button.Icon
    "icon-xs" -> button.IconXs
    "icon-sm" -> button.IconSm
    "icon-lg" -> button.IconLg
    _ -> button.Medium
  }
}

// --- mount: terse API ----------------------------------------------------

pub fn mount_terse(
  selector: String,
  side: String,
  align: String,
  arrow: Bool,
) -> Nil {
  mount_static(
    selector,
    view_terse(parse_side(side), parse_align(align), arrow),
  )
}

// --- views: shadcn examples ----------------------------------------------

/// Terse `popover.popover`: the trigger is the styled button described by
/// `options` (here just the `text` is overridden), and `children` hands back the
/// `Anatomy` for the composable `title`/`description`. `side` / `align` / `arrow`
/// come from the controls via record-update over `popover.options()` — the
/// idiomatic "spread defaults, change a few fields" pattern (auto id and
/// light-dismiss stay default). For a non-button trigger, `popover_with_trigger`.
fn view_terse(side: Side, align: Align, arrow: Bool) -> Element(msg) {
  html.div([attribute.class("text-foreground")], [
    popover.popover(
      options: popover.Options(
        ..popover.options(),
        text: "Open Popover",
        side:,
        align:,
        arrow:,
      ),
      children: fn(pop) {
        [
          popover.header([], [
            popover.title(pop, [], [html.text("Title")]),
            popover.description(pop, [], [html.text("Description text here.")]),
          ]),
        ]
      },
    ),
  ])
}

/// shadcn "Basic": a trigger (variant/size driven by the controls) and a
/// content box with a header.
fn view_basic(
  side: Side,
  align: Align,
  arrow: Bool,
  variant: button.Variant,
  size: button.Size,
  set: IconSet,
  icon_variant: IconVariant,
) -> Element(msg) {
  // Static `lustre.element` view: built exactly once, never re-rendered, so a
  // generated anatomy here is minted once and safe (see `id_gen` call-once).
  let pop = popover.anatomy()
  html.div([attribute.class("text-foreground")], [
    popover.trigger(pop, variant:, size:, attrs: [], children: [
      leading_icon(set, icon_variant, demo_icons.Settings),
      html.text("Open Popover"),
    ]),
    popover.content(
      pop,
      side:,
      align:,
      dismiss: popover.Auto,
      arrow: arrow,
      on_toggle: None,
      attrs: [],
      children: [
        popover.header([], [
          popover.title(pop, [], [html.text("Title")]),
          popover.description(pop, [], [html.text("Description text here.")]),
        ]),
      ],
    ),
  ])
}

// --- view: scroll collision ---------------------------------------------

/// Native popover collision is evaluated against the popup's containing block
/// — for top-layer popups that's always the viewport. In Storybook the canvas
/// iframe **is** that viewport, so the easiest demo is: render an oversized
/// inner div, let the iframe scroll natively, and watch
/// `position-try-fallbacks: flip-block, flip-inline` (set in
/// `gg_base_ui/positioning`) flip the popup as the trigger approaches each
/// edge of the iframe.
///
/// The scrollable surface lives in `helpers/scroll_canvas` (shared with the
/// tooltip collision story); the trigger is centered on mount by
/// `scroll_canvas.center_effect` (wired in `mount_scroll_collision`). Manual
/// dismiss keeps the popup open while you scroll around.
fn view_scroll_collision(
  pop: popover.Anatomy,
  side: Side,
  align: Align,
  arrow: Bool,
  set: IconSet,
  icon_variant: IconVariant,
) -> Element(msg) {
  scroll_canvas.scroll_canvas(
    trigger: popover.trigger(
      pop,
      variant: button.Outline,
      size: button.Medium,
      attrs: [],
      children: [
        leading_icon(set, icon_variant, demo_icons.Settings),
        html.text("Open popover"),
      ],
    ),
    // `Manual`: the popup must survive scrolling/clicking so you can roam the
    // canvas and watch it flip on collision.
    content: popover.content(
      pop,
      side:,
      align:,
      dismiss: popover.Manual,
      arrow: arrow,
      on_toggle: None,
      attrs: [],
      children: [
        popover.header([], [
          popover.title(pop, [], [html.text("Collision detection")]),
          popover.description(pop, [], [
            html.text(
              "Scroll the canvas; this popup flips via "
              <> "`position-try-fallbacks` when it would overflow the iframe.",
            ),
          ]),
        ]),
        html.div([attribute.class("mt-3 flex justify-end")], [
          popover.close(pop, attrs: [], children: [
            leading_icon(set, icon_variant, demo_icons.Close),
            html.text("Close"),
          ]),
        ]),
      ],
    ),
  )
}

// --- view: imperative ---------------------------------------------------

/// Imperative demo of the two orthogonal capabilities on a plain native
/// popover. The **command** capability lets external, non-trigger buttons drive
/// the popover (`popover.show` / `hide` / `toggle`); the **observe** capability
/// (`on_toggle: Some(PopoverOpenChanged)`) mirrors the browser's open state
/// back into the model so the "currently open" label stays honest. The trigger
/// itself is the ordinary native one — no special controlled variant.
fn view_imperative(
  model: ImperativeModel,
  side: Side,
  align: Align,
  set: IconSet,
  icon_variant: IconVariant,
) -> Element(ImperativeMsg) {
  // Rebuild the same deterministic handle `update` uses — no anatomy in the
  // model.
  let pop = popover.anatomy_with_id(imperative_id)
  html.div(
    [attribute.class("flex flex-col items-start gap-3 text-foreground")],
    [
      html.div([attribute.class("flex gap-2")], [
        external_button(ExternalOpenClicked, "Open from outside"),
        external_button(ExternalCloseClicked, "Close from outside"),
        external_button(ExternalToggleClicked, "Toggle from outside"),
      ]),
      popover.trigger(
        pop,
        variant: button.Outline,
        size: button.Medium,
        attrs: [],
        children: [
          leading_icon(set, icon_variant, demo_icons.Settings),
          html.text("Trigger"),
        ],
      ),
      html.p([attribute.class("text-xs text-muted-foreground")], [
        html.text("Popover is currently "),
        html.text(case model.open {
          True -> "open"
          False -> "closed"
        }),
      ]),
      popover.content(
        pop,
        side:,
        align:,
        dismiss: popover.Auto,
        arrow: False,
        on_toggle: Some(PopoverOpenChanged),
        attrs: [],
        children: [
          popover.header([], [
            popover.title(pop, [], [html.text("Imperative popover")]),
            popover.description(pop, [], [
              html.text(
                "Drive it from the external buttons (command) or the trigger; "
                <> "the label below mirrors the native toggle event (observe).",
              ),
            ]),
          ]),
        ],
      ),
    ],
  )
}

/// A decorative leading glyph for a trigger/close button: a real catalog icon
/// tagged `data-icon="inline-start"` (the button recipe's inline-icon spacing),
/// kept `aria-hidden` by `gg_icon.svg` so the button's text owns the name.
/// Generic over `msg`, so it drops into both the static and imperative views.
fn leading_icon(
  set: IconSet,
  variant: IconVariant,
  which: DemoIcon,
) -> Element(msg) {
  demo_icons.render(set, variant, which, [
    attribute.attribute("data-icon", "inline-start"),
  ])
}

/// A plain (non-trigger) button that dispatches one of the command messages —
/// the external control surface for the imperative demo.
fn external_button(
  on_click: ImperativeMsg,
  label: String,
) -> Element(ImperativeMsg) {
  button.button(
    variant: button.Default,
    size: button.Medium,
    attrs: [event.on_click(on_click)],
    children: [html.text(label)],
  )
}

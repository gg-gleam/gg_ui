import gg_icon/icon
import gg_ui/positioning.{
  type Align, type Side, Bottom, Center, End, Left, Right, Start, Top,
}
import gg_ui/ui/button
import gg_ui/ui/tooltip
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import stories/icons/demo_icons.{type IconSet, type IconVariant}

// --- uncontrolled mounts -------------------------------------------------
//
// No model, no msg, no update — the browser owns open/closed via the native
// Interest Invoker + `popover="hint"` lifecycle. `lustre.element` is the right
// tool: a static view rendered once, no event loop in Gleam-land.

fn mount_static(selector: String, view: Element(Nil)) -> Nil {
  let app = lustre.element(view)
  let assert Ok(_) = lustre.start(app, selector, Nil)
  Nil
}

/// shadcn "Basic": a styled trigger (variant/size driven by the controls) and a
/// short text hint. Hover or focus the trigger to show it.
pub fn mount_tooltip_basic(
  selector: String,
  side: String,
  align: String,
  arrow: Bool,
  variant: String,
  size: String,
  delay: Int,
) -> Nil {
  mount_static(
    selector,
    view_basic(
      parse_side(side),
      parse_align(align),
      arrow,
      parse_variant(variant),
      parse_size(size),
      delay,
    ),
  )
}

/// Terse `tooltip.tooltip`: trigger label + tip content in one call, everything
/// else defaulted via `tooltip.options()`.
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

/// Showcase: the four sides, each with an arrow. Hover any trigger to see the
/// hint point back at it (only one hint shows at a time — native `popover="hint"`
/// hides the others).
pub fn mount_sides(selector: String) -> Nil {
  mount_static(selector, view_sides())
}

/// An icon-only trigger built from `trigger_attributes` on a small icon button —
/// the canonical "what does this button do?" tooltip. The glyph is a real
/// catalog icon (`Info`) that follows the Icon set / variant toolbar globals.
pub fn mount_icon(
  selector: String,
  side: String,
  icon_set: String,
  icon_variant: String,
) -> Nil {
  mount_static(
    selector,
    view_icon(
      parse_side(side),
      demo_icons.parse_set(icon_set),
      demo_icons.parse_variant(icon_variant),
    ),
  )
}

// --- views ---------------------------------------------------------------

fn view_basic(
  side: Side,
  align: Align,
  arrow: Bool,
  variant: button.Variant,
  size: button.Size,
  delay: Int,
) -> Element(msg) {
  // Static `lustre.element` view: built exactly once, so a generated anatomy here
  // is minted once and safe (see `id_gen` call-once).
  let tip = tooltip.anatomy()
  html.div([attribute.class("text-foreground")], [
    tooltip.trigger(
      tip,
      variant:,
      size:,
      delay:,
      close_delay: tooltip.default_close_delay,
      children: [html.text("Hover me")],
    ),
    tooltip.content(tip, side:, align:, arrow:, children: [
      html.text("Add to library"),
    ]),
  ])
}

fn view_terse(side: Side, align: Align, arrow: Bool) -> Element(msg) {
  html.div([attribute.class("text-foreground")], [
    tooltip.tooltip(
      label: [html.text("Hover me")],
      options: tooltip.Options(..tooltip.options(), side:, align:, arrow:),
      content: [html.text("Add to library")],
    ),
  ])
}

fn view_sides() -> Element(msg) {
  html.div([attribute.class("grid grid-cols-2 gap-6 text-foreground")], [
    one_side(Top, "Top"),
    one_side(Right, "Right"),
    one_side(Bottom, "Bottom"),
    one_side(Left, "Left"),
  ])
}

fn one_side(side: Side, label: String) -> Element(msg) {
  let tip = tooltip.anatomy()
  html.div([attribute.class("flex justify-center")], [
    tooltip.trigger(
      tip,
      variant: button.Outline,
      size: button.Medium,
      delay: tooltip.default_delay,
      close_delay: tooltip.default_close_delay,
      children: [html.text(label)],
    ),
    tooltip.content(tip, side:, align: Center, arrow: True, children: [
      html.text("On " <> label),
    ]),
  ])
}

fn view_icon(side: Side, set: IconSet, variant: IconVariant) -> Element(msg) {
  html.div([attribute.class("text-foreground")], [
    // Terse `tooltip.tooltip` now that its trigger takes HTML children, not just
    // text: pass the icon (a bigger Lg glyph, whose `size-` token also overrides
    // the button's auto-size) plus a visually-hidden `sr-only` label so the
    // icon-only button still has an accessible name (the a11y addon runs as
    // `error`). A `Ghost` icon button keeps it light — transparent at rest, only
    // a subtle hover surface. (For a truly surfaceless trigger, reach for
    // `tooltip_with_trigger` and a bare element.)
    tooltip.tooltip(
      label: [
        demo_icons.render(set, variant, demo_icons.Info, [icon.size(icon.Lg)]),
        html.span([attribute.class("sr-only")], [html.text("More information")]),
      ],
      options: tooltip.Options(
        ..tooltip.options(),
        variant: button.Ghost,
        size: button.IconSm,
        side:,
        align: Center,
        arrow: True,
      ),
      content: [html.text("More information")],
    ),
  ])
}

// --- args ----------------------------------------------------------------

/// Map the raw Storybook control strings to `Side` / `Align`. Unknown values
/// fall back to the tooltip's default (`Top`/`Center`) so a stray arg can never
/// crash the story.
fn parse_side(side: String) -> Side {
  case side {
    "right" -> Right
    "bottom" -> Bottom
    "left" -> Left
    _ -> Top
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
/// vocabulary in `stories/shared/button-controls.ts`). Safe fallback so a control
/// can't crash.
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

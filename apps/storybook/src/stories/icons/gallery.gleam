//// Icon gallery — the visual proof that every `(set, variant)` renders. A
//// static render-once grid of square tiles; each tile is a tooltip trigger that
//// reveals the icon's name on hover/focus (dogfooding gg_ui's own tooltip).
//// Driven by the `Icon set` / `Icon variant` toolbar globals (threaded in from
//// the `.stories.ts`) — flip a dropdown and the story re-runs with the new set.

import gg_icon/icon
import gg_ui/ui/tooltip
import gleam/list
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import stories/icons/demo_icons.{type DemoIcon, type IconSet, type IconVariant}

pub fn mount_gallery(selector: String, set: String, variant: String) -> Nil {
  let view =
    view_gallery(demo_icons.parse_set(set), demo_icons.parse_variant(variant))
  let assert Ok(_) = lustre.start(lustre.element(view), selector, Nil)
  Nil
}

fn view_gallery(set: IconSet, variant: IconVariant) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "grid grid-cols-4 gap-3 p-2 text-foreground sm:grid-cols-6",
      ),
    ],
    list.map(demo_icons.all(), fn(which) { cell(set, variant, which) }),
  )
}

/// One cell — just the icon, no box. The icon *is* the tooltip trigger, so its
/// name reveals on hover/focus and the grid stays a clean wall of glyphs. Built
/// with `tooltip_with_trigger` + `trigger_attributes` (not the styled button):
/// the icon-only `<button>` carries an `aria-label` so it has an accessible name
/// (the a11y addon runs as `error`), and the icon stays decorative. Resting
/// `text-muted-foreground` brightens on hover/focus — the only affordance, since
/// there's no surrounding box.
fn cell(set: IconSet, variant: IconVariant, which: DemoIcon) -> Element(msg) {
  let name = demo_icons.label(which)
  tooltip.tooltip_with_trigger(
    trigger: fn(anatomy) {
      html.button(
        list.flatten([
          [
            attribute.type_("button"),
            attribute.attribute("aria-label", name),
            attribute.class(
              "flex items-center justify-center rounded-sm p-3 "
              <> "text-muted-foreground transition-colors hover:text-foreground "
              <> "focus-visible:text-foreground focus-visible:outline-2 "
              <> "focus-visible:outline-ring",
            ),
          ],
          tooltip.trigger_attributes(
            anatomy,
            delay: tooltip.default_delay,
            close_delay: tooltip.default_close_delay,
          ),
        ]),
        [demo_icons.render(set, variant, which, [icon.size(icon.Lg)])],
      )
    },
    options: tooltip.options(),
    content: [html.text(name)],
  )
}

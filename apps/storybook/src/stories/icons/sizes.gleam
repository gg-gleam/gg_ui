//// Icon sizes — the typed `icon.Size` scale (`Sm`/`Md`/`Lg`) plus the no-size
//// default, laid out together for comparison. Same boxless treatment as the
//// gallery: each is just the icon, and its size name reveals in a tooltip on
//// hover/focus. Follows the active `Icon set` / `Icon variant` toolbar globals.

import gg_icon/icon.{type Size}
import gg_ui/ui/tooltip
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import stories/icons/demo_icons.{type IconSet, type IconVariant}

/// A recognisable sample glyph for the size demo.
const sample = demo_icons.Settings

pub fn mount_size_scale(
  selector: String,
  icon_set: String,
  icon_variant: String,
) -> Nil {
  let view =
    view_scale(
      demo_icons.parse_set(icon_set),
      demo_icons.parse_variant(icon_variant),
    )
  let assert Ok(_) = lustre.start(lustre.element(view), selector, Nil)
  Nil
}

fn view_scale(set: IconSet, variant: IconVariant) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "flex min-h-24 flex-wrap items-center justify-center gap-8 "
        <> "text-foreground",
      ),
    ],
    list.map(scale_items(), fn(item) {
      let #(label, size) = item
      cell(set, variant, label, size)
    }),
  )
}

/// One boxless glyph at the given size, identical treatment to the gallery: the
/// icon *is* the tooltip trigger (its size is the tip), with an `aria-label` for
/// the a11y addon and resting `text-muted-foreground` brightening on
/// hover/focus.
fn cell(
  set: IconSet,
  variant: IconVariant,
  label: String,
  size: Option(Size),
) -> Element(msg) {
  tooltip.tooltip_with_trigger(
    trigger: fn(anatomy) {
      html.button(
        list.flatten([
          [
            attribute.type_("button"),
            attribute.attribute("aria-label", label),
            attribute.class(
              "inline-flex items-center justify-center rounded-sm p-2 "
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
        [demo_icons.render(set, variant, sample, size_attrs(size))],
      )
    },
    options: tooltip.options(),
    content: [html.text(label)],
  )
}

fn size_attrs(size: Option(Size)) -> List(Attribute(msg)) {
  case size {
    Some(s) -> [icon.size(s)]
    None -> []
  }
}

fn scale_items() -> List(#(String, Option(Size))) {
  [
    #("default", None),
    #("sm", Some(icon.Sm)),
    #("md", Some(icon.Md)),
    #("lg", Some(icon.Lg)),
  ]
}

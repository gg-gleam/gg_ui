//// Icon gallery — the visual proof that every `(set, variant)` renders. A
//// static render-once grid of the whole demo catalog, driven by the `Icon set`
//// / `Icon variant` toolbar globals (threaded in from the `.stories.ts`). Flip a
//// toolbar dropdown and the story re-runs with the new set/variant.

import gg_icon/icon
import gleam/list
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import stories/icons/demo_icons.{type DemoIcon, type IconSet, type IconVariant}

pub fn mount_gallery(selector: String, set: String, variant: String) -> Nil {
  let view = view_gallery(parse_set(set), parse_variant(variant))
  let assert Ok(_) = lustre.start(lustre.element(view), selector, Nil)
  Nil
}

fn parse_set(set: String) -> IconSet {
  case set {
    "tabler" -> demo_icons.Tabler
    _ -> demo_icons.Lucide
  }
}

fn parse_variant(variant: String) -> IconVariant {
  case variant {
    "filled" -> demo_icons.Filled
    _ -> demo_icons.Outline
  }
}

fn view_gallery(set: IconSet, variant: IconVariant) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "grid grid-cols-4 gap-3 p-2 text-foreground sm:grid-cols-5",
      ),
    ],
    list.map(demo_icons.all(), fn(which) { cell(set, variant, which) }),
  )
}

fn cell(set: IconSet, variant: IconVariant, which: DemoIcon) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "flex flex-col items-center justify-center gap-2 rounded-md "
        <> "border border-border p-4",
      ),
    ],
    [
      // Dogfood the typed size scale — the cn-icon-size-lg recipe from the new
      // gg_ui styles/icons.css fragment.
      demo_icons.render(set, variant, which, [icon.size(icon.Lg)]),
      html.span([attribute.class("text-xs text-muted-foreground")], [
        html.text(demo_icons.label(which)),
      ]),
    ],
  )
}

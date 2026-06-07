//// Icon sizes — the typed `icon.Size` scale (`Sm`/`Md`/`Lg`) plus the no-size
//// default. `Playground` is driven by a `size` control; `Scale` lays all four
//// out side by side. Both follow the active `Icon set` / `Icon variant` toolbar
//// globals. Shows the sizing contract: `icon.size(...)` emits a `cn-icon-size-*`
//// class whose `size-` token wins over a container default, while no size at all
//// falls back to `.cn-icon`'s own default (size-4).

import gg_icon/icon.{type Size}
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import stories/icons/demo_icons.{type IconSet, type IconVariant}

/// A recognisable sample glyph for the size demos.
const sample = demo_icons.Settings

pub fn mount_size_playground(
  selector: String,
  size: String,
  icon_set: String,
  icon_variant: String,
) -> Nil {
  let view =
    view_one(
      demo_icons.parse_set(icon_set),
      demo_icons.parse_variant(icon_variant),
      size,
      parse_size(size),
    )
  let assert Ok(_) = lustre.start(lustre.element(view), selector, Nil)
  Nil
}

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

// --- args ----------------------------------------------------------------

/// Map the `size` control string to the typed scale. `"default"` (and any stray
/// value) → `None`, i.e. emit no size class and let `.cn-icon`'s default apply.
fn parse_size(size: String) -> Option(Size) {
  case size {
    "sm" -> Some(icon.Sm)
    "md" -> Some(icon.Md)
    "lg" -> Some(icon.Lg)
    _ -> None
  }
}

fn size_attrs(size: Option(Size)) -> List(Attribute(msg)) {
  case size {
    Some(s) -> [icon.size(s)]
    None -> []
  }
}

fn caption(label: String, size: Option(Size)) -> String {
  case size {
    None -> "default — .cn-icon (size-4)"
    Some(_) -> label <> " — .cn-icon-size-" <> label
  }
}

// --- views ---------------------------------------------------------------

fn view_one(
  set: IconSet,
  variant: IconVariant,
  label: String,
  size: Option(Size),
) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "flex min-h-24 flex-col items-center justify-center gap-3 "
        <> "text-foreground",
      ),
    ],
    [
      demo_icons.render(set, variant, sample, size_attrs(size)),
      html.span([attribute.class("text-xs text-muted-foreground")], [
        html.text(caption(label, size)),
      ]),
    ],
  )
}

fn view_scale(set: IconSet, variant: IconVariant) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "flex min-h-24 flex-wrap items-end justify-center gap-8 "
        <> "text-foreground",
      ),
    ],
    list.map(scale_items(), fn(item) {
      let #(label, size) = item
      html.div([attribute.class("flex flex-col items-center gap-2")], [
        demo_icons.render(set, variant, sample, size_attrs(size)),
        html.span([attribute.class("text-xs text-muted-foreground")], [
          html.text(label),
        ]),
      ])
    }),
  )
}

fn scale_items() -> List(#(String, Option(Size))) {
  [
    #("default", None),
    #("sm", Some(icon.Sm)),
    #("md", Some(icon.Md)),
    #("lg", Some(icon.Lg)),
  ]
}

import birdie
import gg_base_ui/avatar/avatar
import lustre/element
import lustre/element/html

// Both parts stay mounted (the native-first port) — the image carries the
// `data-avatar-image` marker, the root the `data-avatar-root` marker the
// observer keys off.
pub fn image_and_fallback_test() {
  avatar.root(attrs: [], children: [
    avatar.image(src: "/jane.png", alt: "Jane Doe", attrs: []),
    avatar.fallback(attrs: [], children: [html.text("JD")]),
  ])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_base_ui avatar — image + fallback structure")
}

pub fn fallback_only_test() {
  avatar.root(attrs: [], children: [
    avatar.fallback(attrs: [], children: [html.text("JD")]),
  ])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_base_ui avatar — fallback only")
}

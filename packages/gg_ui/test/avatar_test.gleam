import birdie
import gg_ui/ui/avatar
import lustre/element
import lustre/element/html

pub fn classes_default_circle_test() {
  avatar.classes(size: avatar.Default, shape: avatar.Circle)
  |> birdie.snap(title: "gg_ui avatar classes — default / circle")
}

pub fn classes_xs_rounded_test() {
  avatar.classes(size: avatar.Xs, shape: avatar.Rounded)
  |> birdie.snap(title: "gg_ui avatar classes — xs / rounded")
}

pub fn classes_lg_squircle_test() {
  avatar.classes(size: avatar.Lg, shape: avatar.Squircle)
  |> birdie.snap(title: "gg_ui avatar classes — lg / squircle")
}

pub fn render_default_test() {
  avatar.avatar(avatar.Default, avatar.Circle, [], [
    avatar.image(src: "/jane.png", alt: "Jane Doe", attrs: []),
    avatar.fallback([], [html.text("JD")]),
  ])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui avatar render — default")
}

pub fn render_badge_test() {
  avatar.badge([], [])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui avatar badge — render")
}

pub fn render_group_test() {
  avatar.group([], [
    avatar.avatar(avatar.Default, avatar.Circle, [], [
      avatar.fallback([], [html.text("CN")]),
    ]),
    avatar.group_count([], [html.text("+3")]),
  ])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui avatar group — with count")
}

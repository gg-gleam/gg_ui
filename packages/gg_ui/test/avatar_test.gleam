import birdie
import gg_ui/ui/avatar
import gleam/string
import gleeunit/should
import lustre/attribute
import lustre/element
import lustre/element/html

// The badge's default `bg-primary` is raw (not buried in @apply), so a caller's
// colour override in `attrs` wins via tailwind-merge — the default is removed,
// not left to lose on cascade. (The "online green dot" story relies on this.)
pub fn badge_color_override_test() {
  let markup =
    avatar.badge([attribute.class("bg-green-500")], [])
    |> element.to_readable_string

  string.contains(markup, "bg-green-500") |> should.be_true
  string.contains(markup, "bg-primary") |> should.be_false
}

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

//// Story mounts for the styled `Avatar`. Static, render-once views
//// (`lustre.element`) — the avatar has no host state; the image→fallback swap is
//// native (the image paints over the fallback, the headless observer hides it on
//// failure). Dogfoods the kit: the fallback initials + the showcase captions are
//// `gg_ui/ui/text`, and the fallback uses `text.color(text.Inherit)` so the
//// initials inherit the fallback recipe's colour instead of overriding it.

import gg_icon/icon
import gg_icons_lucide/lucide/c as lu_c
import gg_icons_lucide/lucide/u as lu_u
import gg_ui/positioning
import gg_ui/ui/avatar
import gg_ui/ui/button
import gg_ui/ui/popover
import gg_ui/ui/text
import gleam/list
import gleam/option
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

// A real GitHub avatar (loads in Storybook) and a deliberately broken URL (to
// demonstrate the fallback).
const ok_src = "https://avatars.githubusercontent.com/u/124599?v=4"

const broken_src = "https://example.invalid/missing-avatar.png"

pub fn mount_avatar_playground(
  selector: String,
  size: String,
  shape: String,
  broken: Bool,
  initials: String,
) -> Nil {
  let src = case broken {
    True -> broken_src
    False -> ok_src
  }
  let view =
    avatar.avatar(parse_size(size), parse_shape(shape), [], [
      avatar.image(src:, alt: "User avatar", attrs: []),
      avatar.fallback([], [fallback_text(initials)]),
    ])
  let assert Ok(_) = lustre.start(lustre.element(view), selector, Nil)
  Nil
}

pub fn mount_avatar_sizes(selector: String) -> Nil {
  let view =
    row([
      labelled("xs", avatar.avatar(avatar.Xs, avatar.Circle, [], image("CN"))),
      labelled("sm", avatar.avatar(avatar.Sm, avatar.Circle, [], image("CN"))),
      labelled(
        "default",
        avatar.avatar(avatar.Default, avatar.Circle, [], image("CN")),
      ),
      labelled("lg", avatar.avatar(avatar.Lg, avatar.Circle, [], image("CN"))),
    ])
  let assert Ok(_) = lustre.start(lustre.element(view), selector, Nil)
  Nil
}

pub fn mount_avatar_shapes(selector: String) -> Nil {
  let view =
    row([
      labelled(
        "circle",
        avatar.avatar(avatar.Lg, avatar.Circle, [], image("CN")),
      ),
      labelled(
        "rounded",
        avatar.avatar(avatar.Lg, avatar.Rounded, [], image("CN")),
      ),
      labelled(
        "squircle",
        avatar.avatar(avatar.Lg, avatar.Squircle, [], image("CN")),
      ),
    ])
  let assert Ok(_) = lustre.start(lustre.element(view), selector, Nil)
  Nil
}

pub fn mount_avatar_fallbacks(selector: String) -> Nil {
  let view =
    row([
      labelled(
        "image",
        avatar.avatar(avatar.Default, avatar.Circle, [], image("CN")),
      ),
      // No image at all → the fallback shows by default.
      labelled(
        "initials",
        avatar.avatar(avatar.Default, avatar.Circle, [], [
          avatar.fallback([], [fallback_text("JD")]),
        ]),
      ),
      // Broken image → the observer hides it, revealing the initials.
      labelled(
        "failed",
        avatar.avatar(avatar.Default, avatar.Circle, [], [
          avatar.image(src: broken_src, alt: "Missing", attrs: []),
          avatar.fallback([], [fallback_text("ER")]),
        ]),
      ),
      // An icon fallback (lucide user, currentColor → inherits the ground).
      labelled(
        "icon",
        avatar.avatar(avatar.Default, avatar.Circle, [], [
          avatar.fallback([], [lu_u.user([icon.size(icon.Sm)])]),
        ]),
      ),
    ])
  let assert Ok(_) = lustre.start(lustre.element(view), selector, Nil)
  Nil
}

pub fn mount_avatar_badge(selector: String) -> Nil {
  let view =
    row([
      // An online dot (no children) — a colour override for green.
      labelled(
        "online",
        avatar.avatar(
          avatar.Lg,
          avatar.Circle,
          [],
          badged(avatar.badge([attribute.class("bg-green-500")], [])),
        ),
      ),
      // A status icon — the recipe sizes the svg off the avatar size.
      labelled(
        "status",
        avatar.avatar(
          avatar.Lg,
          avatar.Circle,
          [],
          badged(avatar.badge([], [lu_c.check([])])),
        ),
      ),
    ])
  let assert Ok(_) = lustre.start(lustre.element(view), selector, Nil)
  Nil
}

pub fn mount_avatar_group(selector: String) -> Nil {
  let view =
    row([
      labelled("group", avatar.group([], group_avatars())),
      labelled(
        "with count",
        avatar.group(
          [],
          list.append(group_avatars(), [
            avatar.group_count([], [
              text.s6([text.color(text.Inherit)], [html.text("+3")]),
            ]),
          ]),
        ),
      ),
      labelled(
        "with icon",
        avatar.group(
          [],
          list.append(group_avatars(), [
            avatar.group_count([], [lu_u.users([])]),
          ]),
        ),
      ),
    ])
  let assert Ok(_) = lustre.start(lustre.element(view), selector, Nil)
  Nil
}

// Avatar + popover: the avatar as the trigger for an account menu (shadcn's
// "Dropdown" example — we use the native popover, our menu primitive).
pub fn mount_avatar_menu(selector: String) -> Nil {
  let view =
    popover.popover_with_trigger(
      trigger: avatar_trigger,
      options: popover.Options(
        ..popover.options(),
        id: option.Some("avatar-menu"),
        side: positioning.Bottom,
        align: positioning.Start,
      ),
      children: menu_items,
    )
  let assert Ok(_) = lustre.start(lustre.element(view), selector, Nil)
  Nil
}

// --- helpers ----------------------------------------------------------------

fn badged(badge: Element(msg)) -> List(Element(msg)) {
  [
    avatar.image(src: ok_src, alt: "User avatar", attrs: []),
    avatar.fallback([], [fallback_text("CN")]),
    badge,
  ]
}

fn group_avatars() -> List(Element(msg)) {
  list.map(["CN", "LR", "ER"], fn(initials) {
    avatar.avatar(avatar.Default, avatar.Circle, [], image(initials))
  })
}

fn avatar_trigger(anatomy: popover.Anatomy) -> Element(msg) {
  html.button(
    list.append(popover.trigger_attributes(anatomy), [
      attribute.class(
        "rounded-full outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
      ),
    ]),
    [avatar.avatar(avatar.Default, avatar.Circle, [], image("CN"))],
  )
}

fn menu_items(anatomy: popover.Anatomy) -> List(Element(msg)) {
  [
    popover.header([
      popover.title(anatomy, [text.s6_m([], [html.text("My Account")])]),
      popover.description(anatomy, [html.text("shadcn@example.com")]),
    ]),
    menu_item("Profile"),
    menu_item("Billing"),
    menu_item("Settings"),
    menu_item("Log out"),
  ]
}

fn menu_item(label: String) -> Element(msg) {
  button.button(
    button.Ghost,
    button.Sm,
    [attribute.class("w-full justify-start")],
    [
      html.text(label),
    ],
  )
}

fn image(initials: String) -> List(Element(msg)) {
  [
    avatar.image(src: ok_src, alt: "User avatar", attrs: []),
    avatar.fallback([], [fallback_text(initials)]),
  ]
}

// The fallback initials, dogfooded through Text — `Inherit` keeps the recipe's
// colour (the avatar fallback's), only the glyphs change.
fn fallback_text(initials: String) -> Element(msg) {
  text.s6([text.color(text.Inherit)], [html.text(initials)])
}

fn row(children: List(Element(msg))) -> Element(msg) {
  html.div(
    [attribute.class("flex flex-row flex-wrap items-end gap-8 text-foreground")],
    children,
  )
}

fn labelled(caption: String, el: Element(msg)) -> Element(msg) {
  html.div([attribute.class("flex flex-col items-center gap-2")], [
    el,
    text.s7([text.color(text.Muted)], [html.text(caption)]),
  ])
}

fn parse_size(size: String) -> avatar.Size {
  case size {
    "xs" -> avatar.Xs
    "sm" -> avatar.Sm
    "lg" -> avatar.Lg
    _ -> avatar.Default
  }
}

fn parse_shape(shape: String) -> avatar.Shape {
  case shape {
    "rounded" -> avatar.Rounded
    "squircle" -> avatar.Squircle
    _ -> avatar.Circle
  }
}

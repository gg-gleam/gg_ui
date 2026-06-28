//// Story mounts for the base-nova `Button`. Like the popover stories, each
//// `mount_*` starts a fresh Lustre runtime on the canvas Storybook hands us.
//// `Playground` is driven by the `variant` / `size` / `disabled` controls; the
//// galleries render the full set at once, and `AsLink` shows the `classes`
//// recipe applied to an `<a>` (the Lustre stand-in for Base UI's `render`).

import gg_ui/ui/button.{
  type Size, type Variant, Default, Destructive, Ghost, Icon, IconLg, IconSm,
  IconXs, Lg, Link, Medium, Outline, Secondary, Sm, Xs,
}
import gleam/list
import lustre
import lustre/attribute.{type Attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import stories/icons/demo_icons.{type IconSet, type IconVariant}

type Model {
  Model
}

type Msg {
  Noop
}

fn update(model: Model, _msg: Msg) -> #(Model, Effect(Msg)) {
  #(model, effect.none())
}

fn mount(selector: String, view_fn: fn(Model) -> Element(Msg)) -> Nil {
  let app =
    lustre.application(fn(_) { #(Model, effect.none()) }, update, view_fn)
  let assert Ok(_) = lustre.start(app, selector, Nil)
  Nil
}

// --- mounts --------------------------------------------------------------

pub fn mount_playground(
  selector: String,
  variant: String,
  size: String,
  disabled: Bool,
  icon_set: String,
  icon_variant: String,
) -> Nil {
  mount(selector, fn(_model) {
    view_playground(
      parse_variant(variant),
      parse_size(size),
      disabled,
      demo_icons.parse_set(icon_set),
      demo_icons.parse_variant(icon_variant),
    )
  })
}

pub fn mount_variants(selector: String) -> Nil {
  mount(selector, fn(_model) { view_variants() })
}

pub fn mount_sizes(
  selector: String,
  icon_set: String,
  icon_variant: String,
) -> Nil {
  mount(selector, fn(_model) {
    view_sizes(
      demo_icons.parse_set(icon_set),
      demo_icons.parse_variant(icon_variant),
    )
  })
}

pub fn mount_with_icon(selector: String, set: String, variant: String) -> Nil {
  mount(selector, fn(_model) {
    view_with_icon(demo_icons.parse_set(set), demo_icons.parse_variant(variant))
  })
}

pub fn mount_as_link(selector: String) -> Nil {
  mount(selector, fn(_model) { view_as_link() })
}

pub fn mount_class_override(
  selector: String,
  set: String,
  variant: String,
) -> Nil {
  mount(selector, fn(_model) {
    view_class_override(
      demo_icons.parse_set(set),
      demo_icons.parse_variant(variant),
    )
  })
}

// --- args ----------------------------------------------------------------

fn parse_variant(variant: String) -> Variant {
  case variant {
    "destructive" -> Destructive
    "outline" -> Outline
    "secondary" -> Secondary
    "ghost" -> Ghost
    "link" -> Link
    _ -> Default
  }
}

fn parse_size(size: String) -> Size {
  case size {
    "xs" -> Xs
    "sm" -> Sm
    "lg" -> Lg
    "icon" -> Icon
    "icon-xs" -> IconXs
    "icon-sm" -> IconSm
    "icon-lg" -> IconLg
    _ -> Medium
  }
}

// --- views ---------------------------------------------------------------

fn view_playground(
  variant: Variant,
  size: Size,
  disabled: Bool,
  icon_set: IconSet,
  icon_variant: IconVariant,
) -> Element(Msg) {
  // Icon-only buttons have no text node, so they need an explicit accessible
  // name (aria-label); the icon itself is decorative (gg_icon.svg sets
  // aria-hidden). Buttons with visible text don't.
  let #(label, name_attrs) = case size {
    Icon | IconXs | IconSm | IconLg -> #(
      [demo_icons.render(icon_set, icon_variant, demo_icons.Plus, [])],
      [aria_label("Add item")],
    )
    _ -> #([html.text("Button")], [])
  }
  let attrs = case disabled {
    True -> [attribute.disabled(True), event.on_click(Noop)]
    False -> [event.on_click(Noop)]
  }
  center([
    button.button(variant, size, list.flatten([attrs, name_attrs]), label),
  ])
}

fn view_variants() -> Element(Msg) {
  row([
    button.button(Default, Medium, [], [html.text("Default")]),
    button.button(Secondary, Medium, [], [html.text("Secondary")]),
    button.button(Destructive, Medium, [], [html.text("Destructive")]),
    button.button(Outline, Medium, [], [html.text("Outline")]),
    button.button(Ghost, Medium, [], [html.text("Ghost")]),
    button.button(Link, Medium, [], [html.text("Link")]),
  ])
}

fn view_sizes(icon_set: IconSet, icon_variant: IconVariant) -> Element(Msg) {
  let plus = fn() {
    demo_icons.render(icon_set, icon_variant, demo_icons.Plus, [])
  }
  row([
    button.button(Default, Xs, [], [html.text("Extra small")]),
    button.button(Default, Sm, [], [html.text("Small")]),
    button.button(Default, Medium, [], [html.text("Default")]),
    button.button(Default, Lg, [], [html.text("Large")]),
    button.button(Outline, IconXs, [aria_label("Add item")], [plus()]),
    button.button(Outline, IconSm, [aria_label("Add item")], [plus()]),
    button.button(Outline, Icon, [aria_label("Add item")], [plus()]),
    button.button(Outline, IconLg, [aria_label("Add item")], [plus()]),
  ])
}

/// Threads the toolbar's `Icon set` / `Icon variant` globals into real icons
/// from the demo catalog (the icons.md "decorative story icons thread the
/// globals" path). Flipping the toolbar re-runs the story and the glyphs switch
/// set/variant live. The button base recipe sizes the `<svg>` (it carries no
/// `size-` token), so the icon tracks the button — no explicit `icon.size`.
fn view_with_icon(set: IconSet, variant: IconVariant) -> Element(Msg) {
  row([
    button.button(Default, Medium, [], [
      demo_icons.render(set, variant, demo_icons.Plus, [
        attribute.attribute("data-icon", "inline-start"),
      ]),
      html.text("Add item"),
    ]),
    button.button(Outline, Medium, [], [
      html.text("Continue"),
      demo_icons.render(set, variant, demo_icons.ArrowRight, [
        attribute.attribute("data-icon", "inline-end"),
      ]),
    ]),
  ])
}

fn view_as_link() -> Element(Msg) {
  center([
    button.link(
      Link,
      Medium,
      [
        attribute.href("https://ui.shadcn.com/"),
        attribute.target("_blank"),
      ],
      [
        html.text("Inspired by Shadcn UI's Button"),
      ],
    ),
  ])
}

/// Demonstrates a caller `class` override winning over a structural default via
/// tailwind-merge (the shadcn `cn(variants({ className }))` model). The left
/// button is a normal centred button; the right one is widened and passes
/// `justify-between`, which *removes* the component's default `justify-center`
/// (not just appends), so the label and icon spread to the edges. The label is
/// its own `<span>` and the arrow is a real icon, so they're two flex children
/// (adjacent text nodes would collapse into one inline run with nothing to space).
fn view_class_override(set: IconSet, variant: IconVariant) -> Element(Msg) {
  row([
    button.button(Outline, Medium, [attribute.class("w-56")], [
      html.span([], [html.text("Default (centered)")]),
    ]),
    button.button(Outline, Medium, [attribute.class("w-56 justify-between")], [
      html.span([], [html.text("Spread")]),
      demo_icons.render(set, variant, demo_icons.ArrowRight, [
        attribute.attribute("data-icon", "inline-end"),
      ]),
    ]),
  ])
}

// --- helpers -------------------------------------------------------------

fn aria_label(value: String) -> Attribute(Msg) {
  attribute.attribute("aria-label", value)
}

fn center(children: List(Element(Msg))) -> Element(Msg) {
  html.div(
    [
      attribute.class(
        "flex min-h-24 items-center justify-center text-foreground",
      ),
    ],
    children,
  )
}

fn row(children: List(Element(Msg))) -> Element(Msg) {
  html.div(
    [
      attribute.class(
        "flex min-h-24 flex-wrap items-center justify-center gap-3 "
        <> "text-foreground",
      ),
    ],
    children,
  )
}

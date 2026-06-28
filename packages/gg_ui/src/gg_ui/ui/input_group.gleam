//// shadcn-flavoured `InputGroup` — the **thin** styled layer over the headless
//// `gg_base_ui/input_group`. A bordered control row: an `<input>` plus leading /
//// trailing *addons* (icons, text, or buttons). Mirrors shadcn's authoring
//// model (rule 8) — each part emits raw **structural** utilities (layout /
//// positioning, the override surface) plus `cn-*` recipe names for the
//// **themeable** surface, whose Tailwind lives in
//// `styles/shapes/<style>/input-group.css` (scoped under `.style-<name>`). A
//// caller's `class` in `attrs` is folded through `cn.merge`, so an override wins.
//// Grouping semantics (`role="group"`, the structural `data-align` marker, the
//// control slot) come from the headless layer.
////
//// **`gg_base_ui` never appears in this module's public API** (rule 2 facade):
//// the caller-constructed `Align` / `Size` enums are gg_ui's own, mapped to the
//// headless layer through private `*_to_base` functions, so the headless package
//// can be restructured without breaking this surface.
////
//// shadcn's *click-an-addon-to-focus-the-input* behaviour is intentionally not
//// ported yet (see the headless module); clicking the input focuses it natively
//// and a button addon owns its own behaviour.
////
//// Note the `group/input-group` relationship marker on the container: it can't
//// live in the `@apply` recipe (a marker isn't an applyable utility), so it's
//// emitted in markup — faithful to shadcn — giving the addons' `group-*`
//// variants in `styles/shapes/<style>/input-group.css` an ancestor to target.

import gg_base_ui/helpers/cn
import gg_base_ui/input_group/input_group as base_input_group
import gg_ui/ui/button
import gleam/list
import gva
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html

/// Where an addon sits relative to the input. `InlineStart` / `InlineEnd` are the
/// common leading / trailing positions; `BlockStart` / `BlockEnd` stack a
/// full-width addon above / below. gg_ui's own enum (mapped to the headless
/// layer internally).
pub type Align {
  InlineStart
  InlineEnd
  BlockStart
  BlockEnd
}

/// The size of an `InputGroupButton` — the compact sizes shadcn uses for inline
/// affordances. `Xs` / `Sm` are text buttons; `IconXs` / `IconSm` are square
/// icon buttons. Maps onto the styled `button`'s sizes.
pub type Size {
  Xs
  Sm
  IconXs
  IconSm
}

const group_base = "cn-input-group"

const addon_base = "cn-input-group-addon"

const button_base = "cn-input-group-button"

const input_base = "cn-input-group-input"

const text_base = "cn-input-group-text"

type AddonKey {
  AlignKey(Align)
}

/// The container. Wraps the input and its addons into one bordered, focus-aware
/// control row (`role="group"`). `attrs` are merged after the structural ones, so
/// the grouping semantics always hold.
pub fn input_group(
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  html.div(
    list.flatten([
      base_input_group.group_attributes(),
      [attribute.attribute("data-slot", "input-group")],
      // `cn-input-group` carries the themeable recipe; the structural utilities
      // are raw (so a caller can override them), and `group/input-group` is
      // shadcn's named-group marker the addons' `group-*` variants target.
      cn.merge(
        own: group_base
          <> " group/input-group relative flex w-full min-w-0 items-center outline-none has-[>textarea]:h-auto",
        attrs:,
      ),
    ]),
    children,
  )
}

/// A leading / trailing addon slot (`role="group"` + the structural `data-align`
/// marker the container keys layout off). Put an icon, text (`text`), or a
/// `button` inside. `align` decides which edge it sits on and how the input's
/// padding adjusts.
pub fn addon(
  align align: Align,
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  html.div(
    list.flatten([
      base_input_group.addon_attributes(align: align_to_base(align)),
      [attribute.attribute("data-slot", "input-group-addon")],
      cn.merge(
        own: addon_classes(align)
          <> " flex cursor-text items-center justify-center",
        attrs:,
      ),
    ]),
    children,
  )
}

/// The text `<input>`, slotted as the group's control. Carries the slot marker
/// the container's focus-within / invalid CSS targets. A void element — no
/// children; pass `type`, `placeholder`, value/event attrs via `attrs`.
pub fn input(attrs attrs: List(Attribute(msg))) -> Element(msg) {
  html.input(
    list.flatten([
      base_input_group.input_attributes(),
      cn.merge(
        own: input_base <> " flex w-full min-w-0 flex-1 outline-none",
        attrs:,
      ),
    ]),
  )
}

/// A compact inline button addon — shadcn's `InputGroupButton`. A ghost styled
/// `button` at one of the small `Size`s, marked so the group's CSS can tuck it
/// snugly against the edge. Pass your own `event.on_click` / icon children via
/// `attrs` / `children`.
pub fn button(
  size size: Size,
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  // `button` folds its own classes + any `class` in attrs via cn.merge, so the
  // `cn-input-group-button` recipe and a caller override resolve together.
  button.button(
    variant: button.Ghost,
    size: button_size_to_base(size),
    attrs: [
      attribute.attribute("data-slot", "input-group-button"),
      attribute.class(button_base),
      ..attrs
    ],
    children:,
  )
}

/// A muted text addon (`InputGroupText`) — a label, unit, or icon caption sitting
/// beside the input.
pub fn text(
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  html.span(cn.merge(own: text_base <> " flex items-center", attrs:), children)
}

fn addon_classes(align: Align) -> String {
  gva.gva(default: addon_base, resolver: resolve_addon, defaults: [])
  |> gva.with(AlignKey(align))
  |> gva.build
  |> fn(recipe) { cn.cn([recipe]) }
}

fn resolve_addon(key: AddonKey) -> String {
  case key {
    AlignKey(align) -> align_class(align)
  }
}

fn align_class(align: Align) -> String {
  case align {
    InlineStart -> "cn-input-group-addon-align-inline-start"
    InlineEnd -> "cn-input-group-addon-align-inline-end"
    BlockStart -> "cn-input-group-addon-align-block-start"
    BlockEnd -> "cn-input-group-addon-align-block-end"
  }
}

fn align_to_base(align: Align) -> base_input_group.Align {
  case align {
    InlineStart -> base_input_group.InlineStart
    InlineEnd -> base_input_group.InlineEnd
    BlockStart -> base_input_group.BlockStart
    BlockEnd -> base_input_group.BlockEnd
  }
}

fn button_size_to_base(size: Size) -> button.Size {
  case size {
    Xs -> button.Xs
    Sm -> button.Sm
    IconXs -> button.IconXs
    IconSm -> button.IconSm
  }
}

//// shadcn-flavoured `Button` — the **thin** styled layer. Mirrors shadcn's
//// authoring model (its Base UI `style-mira` button): the component emits the
//// **structural / overridable** utilities as *raw Tailwind* right here
//// (`inline-flex items-center justify-center …`), plus the `cn-*` recipe names
//// (`cn-button cn-button-variant-* cn-button-size-*`) whose Tailwind lives in
//// the per-style CSS (`styles/shapes/<style>/button.css`, scoped under
//// `.style-<style>`) and carries only the **themeable surface** (color, radius,
//// rings, font). Keeping the structural utilities raw is what lets a caller's
//// `class` override win — `cn` runs tailwind-merge so e.g. `justify-between`
//// removes the default `justify-center`. This is the layer a future CLI copies.
////
//// Behavior + a11y come from the headless `gg_base_ui/button` layer; this
//// layer only owns appearance and the `data-slot` hook.

import gg_base_ui/button/button as base_button
import gg_base_ui/helpers/cn
import gleam/list
import gva
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html

pub type Variant {
  Default
  Destructive
  Outline
  Secondary
  Ghost
  Link
}

pub type Size {
  Medium
  Xs
  Sm
  Lg
  Icon
  IconXs
  IconSm
  IconLg
}

type Key {
  VariantKey(Variant)
  SizeKey(Size)
}

// `cn-button` carries the per-style themeable surface (in the CSS recipe); the
// rest are raw structural utilities, constant across styles, kept raw so a
// caller's `class` can override them via tailwind-merge (e.g. `justify-between`).
// Mirrors shadcn's Base UI button base string verbatim.
const base = "cn-button group/button inline-flex shrink-0 items-center justify-center whitespace-nowrap transition-all outline-none select-none disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0"

pub fn classes(variant variant: Variant, size size: Size) -> String {
  gva.gva(default: base, resolver: resolve, defaults: [])
  |> gva.with(VariantKey(variant))
  |> gva.with(SizeKey(size))
  |> gva.build
  |> fn(recipe) { cn.cn([recipe]) }
}

pub fn button(
  variant variant: Variant,
  size size: Size,
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  base_button.button(
    config: base_button.config(),
    attrs: [
      attribute.attribute("data-slot", "button"),
      // A caller's `class` (in attrs) folds through tailwind-merge with the
      // component's own classes, so an override wins (the default is removed).
      ..cn.merge(own: classes(variant:, size:), attrs: attrs)
    ],
    children:,
  )
}

pub fn link(
  variant variant: Variant,
  size size: Size,
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  html.a(
    list.flatten([
      base_button.attributes(
        config: base_button.config(),
        target: base_button.NonNative,
      ),
      [attribute.attribute("data-slot", "button")],
      cn.merge(own: classes(variant:, size:), attrs: attrs),
    ]),
    children,
  )
}

fn resolve(key: Key) -> String {
  case key {
    VariantKey(variant) -> variant_class(variant)
    SizeKey(size) -> size_class(size)
  }
}

fn variant_class(variant: Variant) -> String {
  case variant {
    Default -> "cn-button-variant-default"
    Destructive -> "cn-button-variant-destructive"
    Outline -> "cn-button-variant-outline"
    Secondary -> "cn-button-variant-secondary"
    Ghost -> "cn-button-variant-ghost"
    Link -> "cn-button-variant-link"
  }
}

fn size_class(size: Size) -> String {
  case size {
    Medium -> "cn-button-size-default"
    Xs -> "cn-button-size-xs"
    Sm -> "cn-button-size-sm"
    Lg -> "cn-button-size-lg"
    Icon -> "cn-button-size-icon"
    IconXs -> "cn-button-size-icon-xs"
    IconSm -> "cn-button-size-icon-sm"
    IconLg -> "cn-button-size-icon-lg"
  }
}

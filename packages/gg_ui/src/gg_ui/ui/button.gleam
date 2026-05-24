//// shadcn-flavoured `Button` — the **thin** styled layer. Mirrors shadcn's
//// authoring model: the component emits *class names* (`cn-button
//// cn-button-variant-* cn-button-size-*`), never raw Tailwind. The Tailwind
//// recipe for each class lives in the per-style CSS (`styles/nova.css`,
//// scoped under `.style-nova`). This is the layer a future CLI copies into an
//// app and flattens.
////
//// Behavior + a11y come from the headless `gg_base_ui/button` layer; this
//// layer only owns appearance (the `cn-*` names) and the `data-slot` hook.

import gg_base_ui/button/button as base_button
import gg_ui/helpers/cn
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

const base = "cn-button"

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
      attribute.class(classes(variant:, size:)),
      ..attrs
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
      [
        attribute.attribute("data-slot", "button"),
        attribute.class(classes(variant:, size:)),
      ],
      attrs,
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

//// shadcn's `Input` — a thin styled wrapper over the native `<input>`. shadcn's
//// own Input carries **no behaviour** (it's a bare styled element; Base UI's
//// `Input` only adds Field-context wiring, which we don't have yet), so this is a
//// `gg_ui`-only component like `text`: no headless layer, just the `cn-input`
//// recipe (border, focus ring, `aria-invalid` state, disabled) on top of a
//// `<input>`. The `type` and every other native attribute pass straight through
//// `attrs` — `input([attribute.type_("time"), …])` is the time field, `input([…
//// aria-invalid …])` shows the error ring.
////
//// Per rule 8 (the shadcn split): the **structural / overridable** utilities are
//// raw in `base` here (layout/behaviour, constant across styles), while the
//// **themeable** surface (radius, border, bg, ring, colors, sizing) lives in the
//// per-Style recipe `styles/shapes/<style>/input.css`. A caller's `class` (in
//// `attrs`) folds through `cn.merge`, so an override wins — e.g. the date-picker
//// time field passing `bg-background` / `appearance-none`.

import gg_base_ui/helpers/cn
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html

// `cn-input` is the themeable recipe; the rest are raw structural utilities,
// constant across styles and overridable (mirrors shadcn's Input base string).
const base = "cn-input w-full min-w-0 outline-none placeholder:text-muted-foreground disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50"

/// The input's class string — for composing onto your own element (the rare
/// case). Most callers want `input` instead.
pub fn classes() -> String {
  base
}

/// A styled `<input>`. Pass any native attributes through `attrs`: `type`, `value`
/// / `on_input`, `placeholder`, `disabled`, `aria-invalid`, an `id`, extra
/// classes (folded via `cn.merge`), etc.
pub fn input(attrs attrs: List(Attribute(msg))) -> Element(msg) {
  html.input([
    attribute.attribute("data-slot", "input"),
    ..cn.merge(own: base, attrs:)
  ])
}

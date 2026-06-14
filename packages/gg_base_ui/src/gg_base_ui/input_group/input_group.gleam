//// Headless input-group primitive — a Lustre port of shadcn's `InputGroup`
//// family (shadcn composes a bordered control row out of an `<input>` plus
//// leading/trailing *addons* — icons, text, buttons). There is no Base UI
//// `InputGroup` component: this is a shadcn-only structural pattern, so the
//// "behaviour" here is purely **grouping semantics**, not a state machine.
////
//// What this layer owns (a11y + structure only — no Tailwind, no `cn-*`):
////
//// - **`group_attributes`** — `role="group"` for the container, so assistive
////   tech announces the input + its addons as one labelled control cluster.
//// - **`addon_attributes(align)`** — `role="group"` plus a `data-align` marker
////   (`inline-start` / `inline-end` / `block-start` / `block-end`). The marker is
////   *structural*, not cosmetic: the container keys layout off it via
////   `:has(> [data-align=…])` (the addon's ordering / the input's padding), so it
////   must live on the element regardless of styling — exactly how shadcn sets it.
//// - **`input_attributes`** — the slot marker the container's focus-within CSS
////   targets (`[data-slot=input-group-control]`).
////
//// Deliberately omitted (deferred, and not needed by the combobox that motivates
//// this): shadcn's *click-an-addon-to-focus-the-input* nicety. It's a DOM side
//// effect with no model, which needs FFI we don't want to add yet; clicking the
//// input focuses it natively, and an addon that is itself a button owns its own
//// behaviour. Layer it in later behind these same attributes.

import lustre/attribute.{type Attribute}

/// Where an addon sits relative to the input. `InlineStart` / `InlineEnd` are the
/// common leading / trailing positions; `BlockStart` / `BlockEnd` stack a
/// full-width addon above / below (shadcn's block alignments, used with a
/// `<textarea>`). Mirrors shadcn's `align` cva variant.
pub type Align {
  InlineStart
  InlineEnd
  BlockStart
  BlockEnd
}

/// The container's grouping semantics: `role="group"`. Merge onto the element
/// that wraps the input and its addons.
pub fn group_attributes() -> List(Attribute(msg)) {
  [attribute.attribute("role", "group")]
}

/// An addon's structural attributes: its own `role="group"` plus the `data-align`
/// marker the container keys layout off (`:has(> [data-align=…])`). Merge onto the
/// element wrapping a leading/trailing icon, text, or button.
pub fn addon_attributes(align align: Align) -> List(Attribute(msg)) {
  [
    attribute.attribute("role", "group"),
    attribute.attribute("data-align", align_value(align)),
  ]
}

/// The control's slot marker (`data-slot="input-group-control"`) — the hook the
/// container's `focus-within` / `aria-invalid` CSS targets. Merge onto the
/// `<input>` (or `<textarea>`).
pub fn input_attributes() -> List(Attribute(msg)) {
  [attribute.attribute("data-slot", "input-group-control")]
}

fn align_value(align: Align) -> String {
  case align {
    InlineStart -> "inline-start"
    InlineEnd -> "inline-end"
    BlockStart -> "block-start"
    BlockEnd -> "block-end"
  }
}

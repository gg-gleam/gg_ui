//// shadcn-flavoured popover built on the headless `gg_ui/core/popover`. Pure
//// view code (Tailwind class strings + theme tokens) — universal. The host app
//// provides Tailwind and imports `gg_ui/theme.css` for the tokens. This is the
//// layer a future generator CLI would copy into a consuming app.

import gg_ui/core/popover
import gg_ui/core/positioning.{type Placement}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// Styled declarative trigger (also the positioning anchor).
pub fn trigger(state: popover.State, label: String) -> Element(msg) {
  popover.anchor(
    state,
    [
      attribute.class(
        "inline-flex items-center gap-2 rounded-md border border-input "
        <> "bg-background px-4 py-2 text-sm font-medium text-foreground "
        <> "shadow-sm transition-colors hover:bg-accent "
        <> "hover:text-accent-foreground focus-visible:outline-none "
        <> "focus-visible:ring-2 focus-visible:ring-ring",
      ),
    ],
    [html.text(label)],
  )
}

/// Styled floating panel. `on_toggle` mirrors the native open state into your
/// model; `placement` chooses the side/alignment.
pub fn panel(
  state: popover.State,
  placement: Placement,
  on_toggle: fn(Bool) -> msg,
  children: List(Element(msg)),
) -> Element(msg) {
  popover.content(
    state,
    placement,
    on_toggle,
    [
      attribute.class(
        "min-w-48 rounded-md border border-border bg-popover p-4 "
        <> "text-popover-foreground shadow-md outline-none",
      ),
    ],
    children,
  )
}

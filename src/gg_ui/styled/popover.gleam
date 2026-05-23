//// shadcn-flavoured popover built on the headless `gg_ui/popover`. This is the
//// "copy-paste-able" styled layer: pure Tailwind class strings referencing the
//// theme tokens from `gg_ui/theme.css`. No FFI, so it stays universal; the
//// host app provides Tailwind and imports the token stylesheet.

import gg_ui/popover.{type State}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

/// Styled trigger button that doubles as the positioning anchor.
pub fn trigger(state: State, on_toggle: msg, label: String) -> Element(msg) {
  popover.anchor(state, [attribute.class("inline-flex")], [
    html.button(
      [
        event.on_click(on_toggle),
        attribute.class(
          "inline-flex items-center gap-2 rounded-md border border-input "
          <> "bg-background px-4 py-2 text-sm font-medium text-foreground "
          <> "shadow-sm transition-colors hover:bg-accent "
          <> "hover:text-accent-foreground focus-visible:outline-none "
          <> "focus-visible:ring-2 focus-visible:ring-ring",
        ),
      ],
      [html.text(label)],
    ),
  ])
}

/// Styled floating panel. Renders nothing while the popover is closed.
pub fn panel(state: State, children: List(Element(msg))) -> Element(msg) {
  popover.content(
    state,
    [
      attribute.class(
        "z-50 min-w-[12rem] rounded-md border border-border bg-popover p-4 "
        <> "text-popover-foreground shadow-md outline-none",
      ),
    ],
    children,
  )
}

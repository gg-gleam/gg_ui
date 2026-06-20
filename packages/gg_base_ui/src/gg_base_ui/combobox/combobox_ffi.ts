// Combobox FFI — the minimal DOM glue the headless behaviour needs and the
// platform can't do declaratively:
//
// - show/hide the listbox via the native Popover API (top layer + light-dismiss
//   come for free; the `toggle` event syncs the model back),
// - scroll the active option into view as the highlight moves,
// - focus the input when the list opens.
//
// Each has an inert Gleam fallback body, so an SSR render produces the markup
// with no client effect; these run only once the runtime is live. Keep export
// names in sync with the `@external` bindings in `combobox.gleam`.

export function showPopover(listboxId: string): void {
  const el = document.getElementById(listboxId)
  if (el instanceof HTMLElement && !el.matches(":popover-open")) {
    el.showPopover()
  }
}

export function hidePopover(listboxId: string): void {
  const el = document.getElementById(listboxId)
  if (el instanceof HTMLElement && el.matches(":popover-open")) {
    el.hidePopover()
  }
}

export function scrollOptionIntoView(optionId: string): void {
  const el = document.getElementById(optionId)
  el?.scrollIntoView({ block: "nearest" })
}

export function focusInput(inputId: string): void {
  const el = document.getElementById(inputId)
  if (el instanceof HTMLElement) {
    el.focus()
  }
}

// Focus any element by id — used to move roving focus onto a chip (which is
// `tabindex="-1"`, so it's only focusable programmatically).
export function focusElement(id: string): void {
  const el = document.getElementById(id)
  if (el instanceof HTMLElement) {
    el.focus()
  }
}

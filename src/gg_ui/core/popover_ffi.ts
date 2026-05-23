// Popover FFI — the imperative escape hatch for controlled mode only.
//
// Declarative usage (popovertarget + popover="auto") needs no JS at all; this
// exists so app-driven popovers (e.g. a combobox) can force open/close. Keep
// export names in sync with the bindings in `core/popover.gleam`.

export function showPopover(contentId: string): void {
  const el = document.getElementById(contentId);
  if (el instanceof HTMLElement && !el.matches(":popover-open")) {
    el.showPopover();
  }
}

export function hidePopover(contentId: string): void {
  const el = document.getElementById(contentId);
  if (el instanceof HTMLElement && el.matches(":popover-open")) {
    el.hidePopover();
  }
}

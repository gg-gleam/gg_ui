// Popover FFI — the imperative "command" capability: open/close/toggle a
// native popover by content id. Declarative usage (Invoker Commands —
// command="toggle-popover"/"hide-popover" + commandfor) needs no JS at all, and
// the browser maintains aria-expanded on the invoker itself, so there is no
// aria-expanded observer to install here.
//
// The resolved-side observer that arrows depend on lives in `arrow_ffi.ts` —
// it's only needed when arrows are rendered, so the arrow primitive installs
// it on demand.
//
// Keep export names in sync with the bindings in `popover.gleam`.

export function showPopover(contentId: string): void {
  const el = document.getElementById(contentId)
  if (el instanceof HTMLElement && !el.matches(":popover-open")) {
    el.showPopover()
  }
}

export function hidePopover(contentId: string): void {
  const el = document.getElementById(contentId)
  if (el instanceof HTMLElement && el.matches(":popover-open")) {
    el.hidePopover()
  }
}

export function togglePopover(contentId: string): void {
  const el = document.getElementById(contentId)
  if (el instanceof HTMLElement) {
    el.togglePopover()
  }
}

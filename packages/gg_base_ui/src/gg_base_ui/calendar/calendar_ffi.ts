// Calendar FFI — the one piece of DOM glue the headless behaviour needs and the
// platform can't do declaratively: roving focus. After a keyboard move changes
// which day is focused, pull native DOM focus onto that day's button so the
// roving `tabindex` and the visible focus ring follow the arrow keys.
//
// It has an inert Gleam fallback body (in `calendar.gleam`), so an SSR render
// produces the markup with no client effect; this runs only once the runtime is
// live. Keep the export name in sync with the `@external` binding.

export function focusDay(dayId: string): void {
  const el = document.getElementById(dayId)
  if (el instanceof HTMLElement) {
    el.focus()
  }
}

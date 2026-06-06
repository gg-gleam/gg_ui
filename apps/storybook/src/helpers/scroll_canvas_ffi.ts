// Story-helper FFI: center the collision-demo trigger inside the scrollable
// canvas on mount. Replaces the old `autofocus` hack — that only scrolled the
// trigger *into view* and depended on focus actually landing on the button.
//
// We scroll the trigger to the exact center of its scrollable ancestor by
// setting `scrollLeft`/`scrollTop` directly (more reliable than
// `scrollIntoView`, which no-ops for an already-visible element and is fussy
// with absolutely-positioned targets). Deferred one frame so the canvas's
// layout (its viewport-unit size) is settled before we measure.
//
// Pure client effect — the Gleam fallback body never runs.

function scrollableAncestor(el: HTMLElement): HTMLElement | null {
  for (let node = el.parentElement; node; node = node.parentElement) {
    const oy = getComputedStyle(node).overflowY
    if (oy === "auto" || oy === "scroll") return node
  }
  return null
}

// `onDone` runs after the centering scroll has been applied (and a follow-up
// frame, so layout/anchor-positioning reflects the new scroll). Callers use it
// to open a popup *after* the trigger is centered — opening before would resolve
// the popup's side against the off-screen, un-centered trigger.
export function centerInScrollArea(
  triggerId: string,
  onDone: () => void,
): void {
  if (typeof document === "undefined") {
    onDone()
    return
  }
  requestAnimationFrame(() => {
    const trigger = document.getElementById(triggerId)
    const scroller = trigger && scrollableAncestor(trigger)
    if (trigger && scroller) {
      const sr = scroller.getBoundingClientRect()
      const tr = trigger.getBoundingClientRect()
      scroller.scrollLeft += tr.left + tr.width / 2 - (sr.left + sr.width / 2)
      scroller.scrollTop += tr.top + tr.height / 2 - (sr.top + sr.height / 2)
    }
    // One more frame so the scrolled layout settles before `onDone` opens.
    requestAnimationFrame(onDone)
  })
}

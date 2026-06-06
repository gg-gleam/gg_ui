// Arrow FFI — one responsibility:
//
// `ensureResolvedSideObserver`: keeps each open popup's `data-side` attribute
// in sync with the *resolved* side after `position-try-fallbacks` flips. That
// single attribute is the only thing pure CSS can't compute (it needs the
// measured popup/trigger rects); everything that *follows* from it — the arrow's
// geometry, size, placement, and offset — is CSS keyed on `[data-side]` (see
// `styles/shapes/arrow.css`) and on the styled layer's recipes. So this observer
// no longer touches the arrow at all: it measures, decides the side, sets
// `data-side`, and CSS does the rest.
//
// Lives with the arrow rather than the popover because the arrow is what cares
// about the resolved side; popovers without arrows don't need the sync. The
// arrow's renderer (`arrow.arrow`) installs it on first call.
//
// Keep export names in sync with the bindings in `arrow.gleam`.

let resolvedSideObserverInstalled = false

export function ensureResolvedSideObserver(): void {
  if (resolvedSideObserverInstalled) return
  if (typeof document === "undefined") return
  resolvedSideObserverInstalled = true

  document.addEventListener(
    "toggle",
    (event) => {
      const target = event.target
      if (!(target instanceof HTMLElement)) return
      if (!target.hasAttribute("popover")) return
      if ((event as ToggleEvent).newState !== "open") return
      updateResolvedSide(target)
    },
    true,
  )

  // Re-evaluate on viewport changes. rAF coalesces bursts of scroll/resize
  // events into one update per frame.
  let frame = 0
  const schedule = () => {
    if (frame) return
    frame = requestAnimationFrame(() => {
      frame = 0
      for (const el of document.querySelectorAll("[popover]")) {
        if (el instanceof HTMLElement && el.matches(":popover-open")) {
          updateResolvedSide(el)
        }
      }
    })
  }
  window.addEventListener("resize", schedule)
  // Capture-phase so we catch scroll on any ancestor scroller, not just window.
  window.addEventListener("scroll", schedule, true)
}

function updateResolvedSide(popup: HTMLElement): void {
  const trigger = findTriggerFor(popup)
  if (!trigger) return

  const pr = popup.getBoundingClientRect()
  const tr = trigger.getBoundingClientRect()

  // Edge-based: which side of the trigger is the popup fully past? Robust to
  // alignment — a Top+End popup is wider than its trigger, and a
  // center-to-center distance would mis-classify it as "left"; edge-wise it's
  // unambiguously above the trigger.
  let side: "top" | "right" | "bottom" | "left" | null = null
  if (pr.bottom <= tr.top) side = "top"
  else if (pr.top >= tr.bottom) side = "bottom"
  else if (pr.right <= tr.left) side = "left"
  else if (pr.left >= tr.right) side = "right"

  // Fallback for unusual overlapping cases (e.g. a popup that intersects the
  // trigger's box, which shouldn't happen with a non-zero gap but can after
  // try-fallbacks land at an awkward edge).
  if (side === null) {
    const dx = pr.left + pr.width / 2 - (tr.left + tr.width / 2)
    const dy = pr.top + pr.height / 2 - (tr.top + tr.height / 2)
    if (Math.abs(dx) > Math.abs(dy)) {
      side = dx > 0 ? "right" : "left"
    } else {
      side = dy > 0 ? "bottom" : "top"
    }
  }

  // Set the resolved side on the popup. CSS keyed on `[data-side]` swaps the
  // arrow's geometry/placement/offset and the styled layer's flip-away hiding —
  // no per-element rewriting from here.
  if (popup.getAttribute("data-side") !== side) {
    popup.setAttribute("data-side", side)
  }
}

function findTriggerFor(popup: HTMLElement): HTMLElement | null {
  const id = popup.id
  if (!id) return null
  // A popup is opened either by an Invoker Command (popover → `commandfor`) or by
  // an Interest Invoker (tooltip → `interestfor`); match whichever points here so
  // the arrow resolves its side for both components.
  const ref = CSS.escape(id)
  const selector = `[commandfor="${ref}"], [interestfor="${ref}"]`
  const el = document.querySelector(selector)
  return el instanceof HTMLElement ? el : null
}

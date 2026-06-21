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

// Safari sizing fallback (a stopgap — see dev-docs/stateful-components.md). The
// popup is normally sized purely in CSS, relative to the anchor:
//
//   width:          anchor-size(width)
//   max-block-size: min(<cap>, calc(100% - <gap>))   // `100%` = the position-area cell
//
// Safari (≤26.1) ships anchor *positioning* (placement/flip) and resolves
// `anchor-size()`, but does NOT resolve the cell `calc(100%)` for sizing — it
// collapses to ~0, so the popup opens as a thin strip.
//
// Feature-probing this is unreliable: `CSS.supports` reports both as supported,
// and an `anchor-size()` probe passes on Safari (it really does work) while the
// cell-percentage still fails. So instead of guessing capabilities we inspect
// the ACTUAL rendered result on open: if the popup collapsed (tiny box, taller
// content) or overflows the viewport, native sizing failed → measure + clamp
// ourselves, re-fitting on scroll/resize. Where native CSS sized it correctly
// (Chrome) this is a no-op: no overrides, no listeners. Self-adapting — if a
// future Safari fixes the cell-percentage, the check simply stops firing.

// Active teardowns, keyed by popup id, so we detach everything on close.
const fitCleanups = new Map<string, () => void>()

// Installed once: the safety net that guarantees a fit's per-open listeners are
// torn down whenever its popup closes by ANY means — hidePopover, Escape,
// light-dismiss, OR removal from the DOM (the HTML spec runs the hide-popover
// steps on removal, firing `toggle`→closed). Without this, a combobox that
// unmounts while open would leak its window listeners + MutationObserver (the
// `hide` effect never fires on unmount). One permanent document listener, not
// per-instance — no accumulation.
let fitToggleObserverInstalled = false
function ensureFitToggleObserver(): void {
  if (fitToggleObserverInstalled || typeof document === "undefined") return
  fitToggleObserverInstalled = true
  document.addEventListener(
    "toggle",
    (event) => {
      const target = event.target
      if (
        target instanceof HTMLElement &&
        (event as ToggleEvent).newState !== "open" &&
        fitCleanups.has(target.id)
      ) {
        stopFitPopup(target.id)
      }
    },
    true,
  )
}

// Sum the popup's children — the true content height, since the list's options
// live in its scroll overflow even while its flex box is collapsed.
function contentHeight(popup: HTMLElement): number {
  let total = 0
  for (const child of popup.children) {
    if (child instanceof HTMLElement) total += child.scrollHeight
  }
  return total
}

// Native CSS sizing produced a broken box: collapsed (real content present, but
// the box clipped to ~nothing — the Safari cell-percentage failure) or taller
// than the viewport (didn't clamp). A genuinely-empty popup being short is NOT a
// failure, so gate the collapse check on there being content to show.
function nativeSizingFailed(popup: HTMLElement): boolean {
  const h = popup.getBoundingClientRect().height
  if (h > window.innerHeight + 1) return true
  return contentHeight(popup) > 24 && h < 24
}

export function fitPopup(popupId: string, anchorId: string): void {
  const popup = document.getElementById(popupId)
  if (!(popup instanceof HTMLElement)) return
  ensureFitToggleObserver()
  stopFitPopup(popupId)
  // Re-fit on viewport changes AND on content changes (async results arrive a
  // tick after open; the first-open loading state mounts after the fetch starts)
  // — so the height tracks the popup's content rather than freezing at open time.
  // rAF-coalesce bursts (a keystroke re-renders many option nodes) into one
  // measure/write per frame, and `applyFit` self-gates so it's a no-op where the
  // native CSS sized the popup fine (Chrome).
  let frame = 0
  const schedule = () => {
    if (frame) return
    frame = requestAnimationFrame(() => {
      frame = 0
      applyFit(popupId, anchorId)
    })
  }
  const observer = new MutationObserver(schedule)
  observer.observe(popup, { childList: true, subtree: true })
  window.addEventListener("resize", schedule)
  window.addEventListener("scroll", schedule, true)
  fitCleanups.set(popupId, () => {
    if (frame) cancelAnimationFrame(frame)
    observer.disconnect()
    window.removeEventListener("resize", schedule)
    window.removeEventListener("scroll", schedule, true)
  })
  applyFit(popupId, anchorId)
}

export function stopFitPopup(popupId: string): void {
  const cleanup = fitCleanups.get(popupId)
  if (cleanup) {
    cleanup()
    fitCleanups.delete(popupId)
  }
}

function applyFit(popupId: string, anchorId: string): void {
  const popup = document.getElementById(popupId)
  const anchor = document.getElementById(anchorId)
  if (!(popup instanceof HTMLElement) || !(anchor instanceof HTMLElement)) {
    // Popup/anchor gone (closed, or the component unmounted while open) — detach
    // so a stray resize/scroll listener can't outlive the element it serves.
    stopFitPopup(popupId)
    return
  }
  // Measure the NATIVE result with our block-size override removed; if the CSS
  // sized it fine (Chrome, or a future fixed Safari) leave it pure-CSS — no-op.
  if (popup.style.blockSize) popup.style.blockSize = ""
  if (!nativeSizingFailed(popup)) return

  const rect = anchor.getBoundingClientRect()
  // Width is NOT touched: `anchor-size(width)` resolves natively on Safari (the
  // anchor-name sits on the field wrapper), so only the height is broken here.
  //
  // Available space on the facing side; `gap` is the offset margin the
  // positioning layer emitted, `cap` the design max read back out of the
  // emitted `min(<cap>, calc(100% - <gap>))`.
  const cap = popup.style.maxBlockSize.match(/min\(\s*([^,]+?)\s*,/)?.[1]
  const gap = Number.parseFloat(getComputedStyle(popup).marginBlockStart) || 0
  const below = window.innerHeight - rect.bottom - gap
  const above = rect.top - gap
  const available = Math.max(0, below, above)
  // Ceiling for a long list (which then scrolls inside): the design cap, itself
  // clamped to the available space.
  popup.style.maxBlockSize = cap
    ? `min(${cap}, ${available}px)`
    : `${available}px`
  // A DEFINITE height so the `flex-basis:0` list doesn't collapse to nothing —
  // the popup's content height, clamped to the available space. `max-block-size`
  // above still caps an over-long list, which then scrolls within the box.
  popup.style.blockSize = `${Math.min(contentHeight(popup), available)}px`
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

// Keyed debounce (the `useDebounce` analog): each call for a given `key` cancels
// the prior pending timer, so a burst coalesces to one trailing call. Drives the
// component's debounced search-request emission — only the search callback is
// debounced; the input value updates synchronously (never debounced).
const debounceTimers = new Map<string, ReturnType<typeof setTimeout>>()
export function debounce(key: string, delayMs: number, cb: () => void): void {
  const prev = debounceTimers.get(key)
  if (prev) clearTimeout(prev)
  debounceTimers.set(
    key,
    setTimeout(() => {
      // Self-clean: drop the entry before firing so the Map never accumulates a
      // stale timer id (bounded — one per key, removed on fire or on cancel).
      debounceTimers.delete(key)
      cb()
    }, delayMs),
  )
}

// Cancel a pending debounce (e.g. when the list closes) — clears the timer and
// drops the Map entry so nothing fires after teardown and no id lingers.
export function cancelDebounce(key: string): void {
  const prev = debounceTimers.get(key)
  if (prev) {
    clearTimeout(prev)
    debounceTimers.delete(key)
  }
}

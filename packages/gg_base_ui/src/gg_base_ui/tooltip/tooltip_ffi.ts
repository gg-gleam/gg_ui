// Tooltip FFI — Interest Invokers polyfill (Safari).
//
// Tooltips open declaratively via Interest Invokers: the trigger carries
// `interestfor="<hint-id>"` and the browser shows/hides the `popover="hint"`
// target on interest (hover / keyboard focus / long-press), honouring
// `interest-delay-start` / `interest-delay-end`. Safari (≤26.1) has the Popover
// API but NOT Interest Invokers, so the trigger does nothing.
//
// `ensureInterestInvokersPolyfill` shims it where the API is missing: delegated
// pointer/focus listeners show/hide the hint with the same delays. No-op (and no
// listeners) where the API exists, so Chrome/Firefox/SSR are untouched. Delays
// come from `data-interest-delay-start/-end` (plain ms), because a UA without
// Interest Invokers also drops the unknown `interest-delay-*` CSS, so it never
// survives in the inline style for us to read back.
//
// Keep the export name in sync with the binding in `tooltip.gleam`.

let interestPolyfillInstalled = false

export function ensureInterestInvokersPolyfill(): void {
  if (interestPolyfillInstalled) return
  if (typeof document === "undefined") return
  if ("interestForElement" in HTMLButtonElement.prototype) return // native
  interestPolyfillInstalled = true

  // One pending timer per hint, per direction. WeakMap so detached hints don't
  // leak; clearing the opposing timer on each transition prevents open/close
  // races when interest flickers.
  const openTimers = new WeakMap<HTMLElement, number>()
  const closeTimers = new WeakMap<HTMLElement, number>()

  const hintFor = (trigger: HTMLElement): HTMLElement | null => {
    const id = trigger.getAttribute("interestfor")
    const el = id ? document.getElementById(id) : null
    return el instanceof HTMLElement && el.hasAttribute("popover") ? el : null
  }
  const delayMs = (trigger: HTMLElement, attr: string): number => {
    const v = Number.parseInt(trigger.getAttribute(attr) ?? "", 10)
    return Number.isFinite(v) && v > 0 ? v : 0
  }
  const clear = (
    map: WeakMap<HTMLElement, number>,
    hint: HTMLElement,
  ): void => {
    const t = map.get(hint)
    if (t !== undefined) {
      clearTimeout(t)
      map.delete(hint)
    }
  }

  const gainInterest = (trigger: HTMLElement): void => {
    const hint = hintFor(trigger)
    if (!hint) return
    clear(closeTimers, hint)
    if (hint.matches(":popover-open") || openTimers.has(hint)) return
    const t = window.setTimeout(
      () => {
        openTimers.delete(hint)
        // `popover="hint"` closes any other open hint on show — single-hint for
        // free. Guard isConnected: the hint may have been removed during the delay.
        if (hint.isConnected && !hint.matches(":popover-open"))
          hint.showPopover()
      },
      delayMs(trigger, "data-interest-delay-start"),
    )
    openTimers.set(hint, t)
  }

  const loseInterest = (trigger: HTMLElement): void => {
    const hint = hintFor(trigger)
    if (!hint) return
    clear(openTimers, hint)
    if (!hint.matches(":popover-open") || closeTimers.has(hint)) return
    const t = window.setTimeout(
      () => {
        closeTimers.delete(hint)
        if (hint.isConnected && hint.matches(":popover-open"))
          hint.hidePopover()
      },
      delayMs(trigger, "data-interest-delay-end"),
    )
    closeTimers.set(hint, t)
  }

  const triggerFrom = (node: EventTarget | null): HTMLElement | null => {
    if (!(node instanceof Element)) return null
    const el = node.closest("[interestfor]")
    return el instanceof HTMLElement ? el : null
  }

  // pointerover/out bubble (so we can delegate); enter/leave don't.
  document.addEventListener("pointerover", (event) => {
    const trigger = triggerFrom(event.target)
    if (trigger) gainInterest(trigger)
  })
  document.addEventListener("pointerout", (event) => {
    const trigger = triggerFrom(event.target)
    // Ignore moves between the trigger's own descendants (no real leave).
    if (
      trigger &&
      !(
        event.relatedTarget instanceof Node &&
        trigger.contains(event.relatedTarget)
      )
    ) {
      loseInterest(trigger)
    }
  })
  document.addEventListener("focusin", (event) => {
    const trigger = triggerFrom(event.target)
    if (trigger) gainInterest(trigger)
  })
  document.addEventListener("focusout", (event) => {
    const trigger = triggerFrom(event.target)
    if (trigger) loseInterest(trigger)
  })
  // Escape dismisses an open hint (native Interest Invokers do this too).
  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return
    for (const hint of document.querySelectorAll("[popover='hint']")) {
      if (hint instanceof HTMLElement && hint.matches(":popover-open")) {
        hint.hidePopover()
      }
    }
  })
}

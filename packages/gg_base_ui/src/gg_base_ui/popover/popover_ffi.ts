// Popover FFI — the imperative "command" capability: open/close/toggle a
// native popover by content id. Declarative usage (Invoker Commands —
// command="toggle-popover"/"hide-popover" + commandfor) needs no JS at all where
// the API is supported, and the browser maintains aria-expanded on the invoker
// itself. Safari (≤26.1) has the Popover API but NOT Invoker Commands, so there
// the declarative trigger does nothing — `ensureInvokerCommandsPolyfill` shims
// it (see below). No-op everywhere the API exists.
//
// The resolved-side observer that arrows depend on lives in `arrow_ffi.ts` —
// it's only needed when arrows are rendered, so the arrow primitive installs
// it on demand.
//
// Keep export names in sync with the bindings in `popover.gleam`.

// --- Invoker Commands polyfill (Safari) --------------------------------------
//
// Where `command`/`commandfor` aren't supported, run the command in JS: a
// document-level delegated click drives showPopover/hidePopover/togglePopover,
// and a toggle listener keeps the trigger's aria-expanded in sync (including
// closes we didn't cause — Escape, light-dismiss). Installed once, on demand,
// and only when the native API is missing — so Chrome/Firefox are untouched.
//
// The one subtlety is `popover="auto"` light-dismiss: clicking the trigger of an
// OPEN auto popover light-dismisses it on pointerdown (the trigger is "outside"
// the popup, and without native Invoker Commands it isn't an associated
// invoker), so a naive toggle on the following click would immediately reopen
// it. We capture the open-state at pointerdown — before light-dismiss runs — and
// decide toggle direction from that, so the gesture reads as "close".

let invokerPolyfillInstalled = false

export function ensureInvokerCommandsPolyfill(): void {
  if (invokerPolyfillInstalled) return
  if (typeof document === "undefined") return
  if ("command" in HTMLButtonElement.prototype) return // native: nothing to do
  invokerPolyfillInstalled = true

  let pending: { target: HTMLElement; wasOpen: boolean } | null = null

  document.addEventListener(
    "pointerdown",
    (event) => {
      const target = commandTargetFrom(event.target)
      pending = target
        ? { target, wasOpen: target.matches(":popover-open") }
        : null
    },
    true,
  )

  document.addEventListener("click", (event) => {
    const invoker = invokerFrom(event.target)
    if (!invoker) return
    const target = commandTarget(invoker)
    if (!target) return
    const command = invoker.getAttribute("command")
    const wasOpen =
      pending && pending.target === target
        ? pending.wasOpen
        : target.matches(":popover-open")
    pending = null
    if (command === "toggle-popover") {
      if (wasOpen) target.hidePopover()
      else target.showPopover()
    } else if (command === "show-popover") {
      target.showPopover()
    } else if (command === "hide-popover") {
      target.hidePopover()
    } else {
      return
    }
    syncExpanded(target)
  })

  document.addEventListener(
    "toggle",
    (event) => {
      const t = event.target
      if (t instanceof HTMLElement && t.hasAttribute("popover")) syncExpanded(t)
    },
    true,
  )
}

function invokerFrom(node: EventTarget | null): HTMLElement | null {
  if (!(node instanceof Element)) return null
  const el = node.closest("[commandfor][command]")
  return el instanceof HTMLElement ? el : null
}

function commandTarget(invoker: HTMLElement): HTMLElement | null {
  const id = invoker.getAttribute("commandfor")
  const el = id ? document.getElementById(id) : null
  return el instanceof HTMLElement && el.hasAttribute("popover") ? el : null
}

function commandTargetFrom(node: EventTarget | null): HTMLElement | null {
  const invoker = invokerFrom(node)
  return invoker ? commandTarget(invoker) : null
}

// Mirror aria-expanded onto the disclosure trigger(s) only (command=
// toggle-popover) — not the in-popup close button (command=hide-popover).
function syncExpanded(popup: HTMLElement): void {
  if (!popup.id) return
  const open = popup.matches(":popover-open")
  const sel = `[commandfor="${CSS.escape(popup.id)}"][command="toggle-popover"]`
  for (const invoker of document.querySelectorAll(sel)) {
    invoker.setAttribute("aria-expanded", open ? "true" : "false")
  }
}

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

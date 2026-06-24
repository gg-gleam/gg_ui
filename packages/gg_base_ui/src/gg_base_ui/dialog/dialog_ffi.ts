// Dialog FFI — the client-only glue behind the headless `<dialog>` boundary.
// Everything declarative (the `command="show-modal"`/`"close"` Invoker Commands,
// `closedby` light-dismiss, focus trap, `::backdrop`, Escape) is native and
// needs no JS where the platform supports it. This file covers the two gaps:
//
//   1. The imperative "command" capability — open/close a dialog by content id
//      (`showModal` / `closeDialog`), used by the `open` / `close` effects.
//   2. `ensureDialogPolyfill` — Safari (≤26.1) has `<dialog>` but NOT Invoker
//      Commands and NOT `closedby`, so the declarative trigger/close buttons and
//      backdrop light-dismiss do nothing there. We shim both, on demand, only
//      when the native API is missing — Chrome/Firefox are untouched.
//
// Keep export names in sync with the bindings in `dialog.gleam`.

let polyfillInstalled = false

export function ensureDialogPolyfill(): void {
  if (polyfillInstalled) return
  if (typeof document === "undefined") return
  polyfillInstalled = true

  installInvokerFallback()
  installLightDismissFallback()
  installExpandedSync()
}

// --- Invoker Commands fallback (Safari) --------------------------------------
//
// Where `command`/`commandfor` aren't supported, run the dialog commands in JS
// via a document-level delegated click. Unlike popover (one toggle button), a
// dialog uses separate open/close invokers, so there's no light-dismiss race to
// reason about — each click maps to exactly one action.

function installInvokerFallback(): void {
  if ("commandForElement" in HTMLButtonElement.prototype) return // native

  document.addEventListener("click", (event) => {
    const invoker = invokerFrom(event.target)
    if (!invoker) return
    const dialog = commandTarget(invoker)
    if (!dialog) return
    const command = invoker.getAttribute("command")
    if (command === "show-modal") {
      if (!dialog.open) dialog.showModal()
    } else if (command === "close" || command === "request-close") {
      if (dialog.open) dialog.close()
    }
  })
}

function invokerFrom(node: EventTarget | null): HTMLElement | null {
  if (!(node instanceof Element)) return null
  const el = node.closest("[commandfor][command]")
  return el instanceof HTMLElement ? el : null
}

function commandTarget(invoker: HTMLElement): HTMLDialogElement | null {
  const id = invoker.getAttribute("commandfor")
  const el = id ? document.getElementById(id) : null
  return el instanceof HTMLDialogElement ? el : null
}

// --- closedby="any" light-dismiss fallback (Safari) --------------------------
//
// Native `closedby="any"` closes a modal dialog when the backdrop is clicked.
// Where it's unsupported, detect a backdrop click ourselves: a click whose
// target IS the dialog element (content clicks target inner nodes) and whose
// coordinates fall OUTSIDE the dialog's content box. Only dialogs that opted in
// with `closedby="any"` are dismissed.

function installLightDismissFallback(): void {
  if ("closedBy" in HTMLDialogElement.prototype) return // native

  document.addEventListener("click", (event) => {
    const dialog = event.target
    if (!(dialog instanceof HTMLDialogElement) || !dialog.open) return
    if (dialog.getAttribute("closedby") !== "any") return

    const rect = dialog.getBoundingClientRect()
    const insideContent =
      rect.top <= event.clientY &&
      event.clientY <= rect.bottom &&
      rect.left <= event.clientX &&
      event.clientX <= rect.right
    if (!insideContent) dialog.close()
  })
}

// --- aria-expanded sync ------------------------------------------------------
//
// Native browsers reflect the trigger's disclosure state into the accessibility
// tree themselves (the DOM `aria-expanded` attribute stays at its SSR seed, like
// popover). To keep Safari — where the Invoker Commands fallback above drives
// the dialog — accessible, mirror the open state onto the trigger's DOM
// attribute: set it on `show-modal`, and clear it from the native `close` event
// (which fires for every close path: Escape, light-dismiss, a close button, the
// `close` effect). Harmless on native browsers (it just re-asserts `false`).

function installExpandedSync(): void {
  if ("commandForElement" in HTMLButtonElement.prototype) {
    // Native invokers own the AX state; only wire the close-side reset.
    document.addEventListener("close", onDialogClose, true)
    return
  }

  document.addEventListener("click", (event) => {
    const invoker = invokerFrom(event.target)
    if (!invoker || invoker.getAttribute("command") !== "show-modal") return
    const dialog = commandTarget(invoker)
    if (dialog) setExpanded(dialog, true)
  })
  document.addEventListener("close", onDialogClose, true)
}

function onDialogClose(event: Event): void {
  const dialog = event.target
  if (dialog instanceof HTMLDialogElement) setExpanded(dialog, false)
}

function setExpanded(dialog: HTMLDialogElement, open: boolean): void {
  if (!dialog.id) return
  const sel = `[commandfor="${CSS.escape(dialog.id)}"][command="show-modal"]`
  for (const trigger of document.querySelectorAll(sel)) {
    trigger.setAttribute("aria-expanded", open ? "true" : "false")
  }
}

// --- Imperative command capability -------------------------------------------

export function showModal(contentId: string): void {
  const el = document.getElementById(contentId)
  if (el instanceof HTMLDialogElement && !el.open) el.showModal()
}

export function closeDialog(contentId: string): void {
  const el = document.getElementById(contentId)
  if (el instanceof HTMLDialogElement && el.open) el.close()
}

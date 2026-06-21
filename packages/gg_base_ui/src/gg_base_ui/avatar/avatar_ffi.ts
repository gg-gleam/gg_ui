// Avatar FFI — a single, idempotent capture-phase observer that mirrors the
// image's load result onto the avatar root as `data-status`, so the styled
// layer's CSS can suppress the broken-image glyph on failure (revealing the
// fallback that's stacked behind). This is the only client-side behavior the
// native-first avatar needs: the happy path (image paints over the fallback) is
// pure markup + CSS, so on the BEAM the Gleam fallback runs nothing and SSR
// still renders correctly.
//
// `load`/`error` events do NOT bubble, so we delegate from the document in the
// CAPTURE phase — one pair of listeners covers every avatar on the page, present
// or future, without per-image wiring. We key off the `data-avatar-image`
// behavior marker (set by `avatar.image`) and write to the closest
// `[data-avatar-root]`.
//
// Keep the export name in sync with the binding in `avatar.gleam`.

let installed = false

export function ensureAvatarObserver(): void {
  if (installed) return
  if (typeof document === "undefined") return
  installed = true

  document.addEventListener("error", (event) => mark(event, "error"), true)
  document.addEventListener("load", (event) => mark(event, "loaded"), true)
}

function mark(event: Event, status: "loaded" | "error"): void {
  const target = event.target
  if (!(target instanceof Element)) return
  if (!target.matches("img[data-avatar-image]")) return
  const root = target.closest("[data-avatar-root]")
  root?.setAttribute("data-status", status)
}

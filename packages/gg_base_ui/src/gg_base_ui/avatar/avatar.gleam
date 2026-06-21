//// Headless avatar, native-first — a Lustre port of Base UI's `Avatar.*`
//// anatomy (`Root` / `Image` / `Fallback`).
////
//// Base UI tracks the image's load status in React state
//// (`idle`/`loading`/`loaded`/`error`) and conditionally mounts the parts: the
//// `Image` renders only once `loaded`, the `Fallback` only while *not* loaded.
//// We reach the same visual result without a JS state machine, leaning on the
//// platform (rule 3 — identical on JS *and* the BEAM):
////
//// - **Both parts stay mounted.** The `<img>` is stacked *over* the fallback;
////   once it paints it covers the fallback, and while it's still loading (or
////   when no image is provided at all) the fallback shows through. So SSR
////   round-trips the whole structure and there's no mount/unmount churn.
//// - **The one client-only nicety** is suppressing the broken-image glyph when
////   the image *fails* to load. A single idempotent **capture-phase** observer
////   (`ensure_avatar_observer`, installed when `image` is first built) flips
////   `data-status="error"` on the avatar root, so the styled layer's CSS can
////   hide the failed `<img>` and reveal the fallback. On the BEAM the Erlang
////   fallback is a no-op, so SSR renders the markup with no client effect — the
////   same FFI-behind-the-headless-boundary pattern popover uses for its invoker
////   polyfill. (`load`/`error` don't bubble, hence capture-phase delegation.)
////
//// Behavior markers `data-avatar-root` / `data-avatar-image` are headless-owned
//// — the observer keys off them. Styling hooks (`data-slot`, `cn-*`) are added
//// by the styled `gg_ui/ui/avatar` layer on top.
////
//// Base UI's `Fallback` `delay` (hold the fallback back for N ms to avoid a
//// flash on fast connections) is deliberately out of scope: with both parts
//// mounted the image simply paints over the fallback the instant it's ready, so
//// there's no fallback-then-image swap to delay.

import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html

/// The avatar container. Renders a `<span>` carrying the `data-avatar-root`
/// behavior marker the observer targets; compose an `image` and/or a `fallback`
/// inside it.
pub fn root(
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  html.span([attribute.attribute("data-avatar-root", ""), ..attrs], children)
}

/// The image. Renders an `<img>` with `src` + `alt` and the `data-avatar-image`
/// behavior marker. Building it installs the broken-image observer (idempotent,
/// no-op on the BEAM). Stack it over a `fallback` sibling.
pub fn image(
  src src: String,
  alt alt: String,
  attrs attrs: List(Attribute(msg)),
) -> Element(msg) {
  let Nil = ensure_avatar_observer()
  html.img([
    attribute.src(src),
    attribute.alt(alt),
    attribute.attribute("data-avatar-image", ""),
    ..attrs
  ])
}

/// Rendered behind the image — shown when no image is provided, while it loads,
/// or when it fails. Renders a `<span>`; `children` is the fallback content
/// (initials, an icon, …).
pub fn fallback(
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  html.span(attrs, children)
}

// Idempotent install of the capture-phase load/error observer. Called by `image`
// so any avatar on the page gets the broken-image suppression for free. A no-op
// where already installed, and on the BEAM (the Erlang fallback never runs an
// effect — markup still renders server-side).
@external(javascript, "./avatar_ffi.ts", "ensureAvatarObserver")
fn ensure_avatar_observer() -> Nil {
  Nil
}

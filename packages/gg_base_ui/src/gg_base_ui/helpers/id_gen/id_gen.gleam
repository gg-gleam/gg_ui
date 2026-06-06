//// Unique-ID generator — the Lustre analogue of React's [`useId`](
//// https://react.dev/reference/react/useId). Component primitives (popover,
//// form fields, …) need stable ids to wire `id`/`for`/`aria-*`/`commandfor`
//// associations. Asking the *caller* to invent that id leaks an
//// implementation detail and risks two instances colliding on the same string.
//// `generate` hands out a fresh, collision-free id instead.
////
//// **Counter, not randomness.** Like `useId`, the value only needs to be
//// *unique* and *stable*, never unguessable. A monotonic counter is
//// collision-proof within a runtime (every Lustre app on the page shares the
//// counter) and — unlike `crypto.randomUUID` — increments in a predictable
//// order, which keeps a future server render and its client hydration agreeing
//// on ids far better than randomness would.
////
//// **Multi-target.** This kit targets both Erlang and JavaScript, so the
//// counter is implemented natively on each: a module-level integer on JS, and
//// `erlang:unique_integer/1` (a zero-setup BEAM built-in) on Erlang. Either
//// way you get unique ids on whichever runtime is doing the rendering.
////
//// **Call once, then reuse — this is the one rule.** Lustre re-runs `view` on
//// every model change; minting a fresh id per render would change the id out
//// from under the very association it wires (the `commandfor` link, the
//// `for`/`id` pair, …). Generate in `init` and store the id (or the struct
//// built from it) in your model, or once at the top of a render-once static
//// view, then thread it through `view`. This mirrors `useId`, which a
//// component calls exactly once per instance.

/// Native counter step. JS: post-increment a module-level integer. Erlang:
/// `erlang:unique_integer([positive, monotonic])`. Returns `"<prefix>-<n>"`.
@external(erlang, "gg_base_ui_id_gen_ffi", "next_id")
@external(javascript, "./id_gen_ffi.ts", "nextId")
fn next_id(prefix: String) -> String

/// A fresh unique id with the default `"gg"` prefix (e.g. `"gg-0"`). Call once
/// per component instance and reuse the result — see the module docs.
pub fn generate() -> String {
  next_id("gg")
}

/// Like `generate`, but with a caller-supplied prefix for readable ids in the
/// DOM / devtools (e.g. `generate_with_prefix("dialog")` → `"dialog-7"`). The
/// prefix is cosmetic; uniqueness comes from the shared counter, so distinct
/// prefixes never need to be globally distinct to stay collision-free.
pub fn generate_with_prefix(prefix: String) -> String {
  next_id(prefix)
}

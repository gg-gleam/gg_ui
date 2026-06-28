//// Whole-string merge-result cache — a render-time optimization.
////
//// `cached(key, compute)` returns the memoized result for `key`, or runs
//// `compute()` once and stores it. It is **JS-only**: the browser is where the
//// same class strings get merged thousands of times (a Lustre `view` re-runs on
//// every state change), so an LRU there pays off. On the BEAM the Gleam fallback
//// body below runs — it just calls `compute()` with **no caching** (SSR renders
//// once; if Lustre *server components* ever prove a hot merge path, swap this
//// fallback for an ETS-backed impl behind the same signature, no API change).
////
//// Because the cache changes only speed, never output, JS-cached and BEAM-
//// uncached produce identical bytes — so it doesn't break the dual-target rule.
//// The result of a merge depends only on the input string (gg_cn ships a single
//// baked config), so a global input→output cache is always correct.
////
//// The `compute` thunk is a plain Gleam function; passing it across the FFI
//// boundary avoids constructing a Gleam `Result` in JS (no prelude import), and
//// a cached value is always a `String` so JS can use `undefined` as the miss
//// sentinel cleanly.

@external(javascript, "./cache_ffi.mjs", "cached")
pub fn cached(_key: String, compute: fn() -> String) -> String {
  // BEAM (and any non-JS target): no cache — recompute every call.
  compute()
}

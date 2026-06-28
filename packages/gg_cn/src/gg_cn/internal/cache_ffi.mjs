// Whole-string merge-result LRU for `cache.gleam` (JS only — the BEAM uses the
// Gleam fallback, which doesn't cache). Two-generation null-prototype maps: when
// the live generation fills past CACHE_SIZE it rotates into `previous` instead
// of evicting per entry, so the write path stays allocation-free in the common
// case. Mirrors tailwind-merge's default whole-string cache (size 500).
//
// `cached(key, compute)` returns the memoized result or runs the Gleam `compute`
// thunk once and stores it. A cached value is always a string, so `undefined`
// from `Map.get` is an unambiguous miss sentinel.

const CACHE_SIZE = 500

let cache = new Map()
let previous = new Map()

export function cached(key, compute) {
  const live = cache.get(key)
  if (live !== undefined) return live

  // Reuse a value from the previous generation if present, else compute. Either
  // way it's written into the live generation (promoting a hot key past the next
  // rotation) and the size check runs on every write, so `cache` never exceeds
  // CACHE_SIZE + 1 before rotating — a strict ~2×CACHE_SIZE bound on live entries.
  let result = previous.get(key)
  if (result === undefined) result = compute()

  cache.set(key, result)
  if (cache.size > CACHE_SIZE) {
    previous = cache
    cache = new Map()
  }
  return result
}

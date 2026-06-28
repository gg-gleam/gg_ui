//// gg_cn — a pure-Gleam `tailwind-merge`.
////
//// Ported from [cnfast](https://github.com/aidenybai/cnfast)'s logic engine
//// (itself a faithful reimplementation of `tailwind-merge` v4), this resolves
//// conflicting Tailwind utility classes by keeping the last one per conflict
//// group: `tw_merge("px-2 px-4") == "px-4"`.
////
//// This is the engine behind `gg_base_ui/helpers/cn` (which `gg_ui` and its
//// components use): a real `clsx + tailwind-merge`, for any markup that mixes
//// raw Tailwind utilities and needs conflict resolution. It is pure Gleam (no
//// FFI), so it compiles and behaves identically on JS and the BEAM — which is
//// why it can back gg_ui's `cn` without bringing Elixir `tails` into the build.
////
//// ## Usage
////
//// ```gleam
//// import gg_cn
////
//// let merge = gg_cn.new()
//// merge |> gg_cn.tw_merge("px-2 py-1 px-4")   // "py-1 px-4"
//// ```
////
//// `new()` builds the class trie once (it is moderately expensive); reuse the
//// returned `Merger` across calls rather than rebuilding it per merge. For
//// render-time callers, prefer [`default`](#default) — a process-global `Merger`
//// built once and reused (what `gg_base_ui/helpers/cn` uses).

import gleam/list
import gleam/string
import global_value

import gg_cn/internal/config
import gg_cn/internal/merge
import gg_cn/internal/validators

/// A prepared merge engine: the compiled regexes and built class trie. Build it
/// once with [`new`](#new) and reuse it.
pub opaque type Merger {
  Merger(engine: merge.Engine)
}

/// Build a `Merger` from the baked-in Tailwind v4 configuration.
pub fn new() -> Merger {
  let regexes = validators.compile()
  let cfg = config.default_config(regexes)
  Merger(engine: merge.new(cfg))
}

/// A process-global default `Merger`, built **once** on first use and reused
/// forever after. Backed by `global_value` (persistent_term on the BEAM, a
/// singleton object on JS), so the expensive trie + regex build happens a single
/// time per runtime — the right thing for render-time callers (e.g. gg_ui's
/// `cn`) that shouldn't thread a `Merger` around or rebuild it per call.
///
/// This memoizes only the *engine* (the trie). It does not yet cache per-input
/// merge *results*; that LRU is a separate, optional layer (see the package
/// README / gg_ui follow-up).
pub fn default() -> Merger {
  global_value.create_with_unique_name("gg_cn.default_merger", new)
}

/// A class value, mirroring `clsx`/`tailwind-merge`'s accepted inputs: a string,
/// a conditional (a `Bool` gate paired with a class string), or a nested list.
pub type ClassValue {
  Class(String)
  /// `When(condition, classes)` contributes `classes` only when `condition`.
  When(Bool, String)
  Group(List(ClassValue))
}

// --- twJoin / clsx ------------------------------------------------------------

/// Join class values into one space-separated string, dropping falsy/empty
/// parts — the `twJoin`/`clsx` step, without conflict resolution.
pub fn tw_join(values: List(ClassValue)) -> String {
  values
  |> list.map(resolve_value)
  |> list.filter(fn(part) { part != "" })
  |> string.join(" ")
}

fn resolve_value(value: ClassValue) -> String {
  case value {
    Class(class) -> class
    When(True, class) -> class
    When(False, _) -> ""
    Group(values) -> tw_join(values)
  }
}

// --- twMerge ------------------------------------------------------------------

/// Merge an already-joined, space-separated class string, resolving conflicts.
pub fn tw_merge(merger: Merger, class_list: String) -> String {
  merge.merge_class_list(merger.engine, class_list)
}

/// `clsx` + `twMerge` in one — the shadcn `cn` helper. Joins the class values,
/// then resolves conflicts.
pub fn cn(merger: Merger, values: List(ClassValue)) -> String {
  tw_merge(merger, tw_join(values))
}

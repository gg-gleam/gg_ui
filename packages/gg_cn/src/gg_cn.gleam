//// gg_cn — a pure-Gleam `tailwind-merge`.
////
//// Ported from [cnfast](https://github.com/aidenybai/cnfast)'s logic engine
//// (itself a faithful reimplementation of `tailwind-merge` v4), this resolves
//// conflicting Tailwind utility classes by keeping the last one per conflict
//// group: `tw_merge("px-2 px-4") == "px-4"`.
////
//// Unlike `gg_ui/helpers/cn` — a plain whitespace-collapsing join used because
//// gg_ui emits non-conflicting semantic `cn-*` names — this is the real merge
//// engine, for consumers who *do* mix raw Tailwind utilities and need conflict
//// resolution. It is pure Gleam (no FFI), so it compiles and behaves
//// identically on JS and the BEAM.
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
//// returned `Merger` across calls rather than rebuilding it per merge. The
//// top-level `tw_merge`/`cn` helpers build a fresh `Merger` per call for
//// convenience — fine for one-offs, but bind `new()` once on a hot path.

import gleam/list
import gleam/string

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

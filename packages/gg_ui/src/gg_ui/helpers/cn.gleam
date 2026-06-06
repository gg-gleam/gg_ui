//// Class composer — the shadcn `cn` analogue for Gleam. Joins class-name
//// fragments into one space-separated string, collapsing any empty fragments
//// or repeated whitespace so the result is clean and stable.
////
//// gg_ui emits **semantic `cn-*` class names**, never raw Tailwind utilities,
//// so there are never conflicting utilities to reconcile — a plain join is
//// correct, and tailwind-merge would do no real work here beyond whitespace
//// tidying (which we do directly). Keeping it pure Gleam (no FFI, no
//// tailwind-merge/`tails` dependency) is also what lets `cn` compile and behave
//// identically on JS *and* the BEAM — see `dev-docs/vision.md` "Both targets,
//// or it doesn't ship" and `dev-docs/composition.md`.

import gleam/list
import gleam/string

/// Join class-name fragments into one clean, space-separated class string.
pub fn cn(fragments: List(String)) -> String {
  fragments
  |> string.join(" ")
  |> string.split(" ")
  |> list.filter(fn(token) { token != "" })
  |> string.join(" ")
}

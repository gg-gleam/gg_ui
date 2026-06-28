//// Class composer — the shadcn `cn` analogue for Gleam, backed by the real
//// `clsx + tailwind-merge` engine (`gg_cn`).
////
//// Lives in `gg_base_ui` (not the ejected styled layer) on purpose: it's a
//// pure-Gleam helper both `gg_ui` and the CLI-ejected `ui/` import, so keeping
//// it here means it is **imported, never copied/frozen into user code** — we can
//// fix it (or follow a Lustre change) once and every consumer gets it. The
//// headless package still emits **no Tailwind/CSS**; it merely *holds* this
//// shared class helper (pure Gleam, no stylesheet).
////
//// shadcn keeps a component's **structural / overridable** utilities as raw
//// Tailwind right in the component string (`inline-flex items-center
//// justify-center …`) and puts only the **themeable surface** in the `cn-*`
//// `@apply` recipe. Because the overridable utilities are raw, a caller's class
//// override (e.g. `justify-between`) can win — `cn` runs tailwind-merge so the
//// conflicting default (`justify-center`) is *removed*, not just out-ordered
//// (CSS cascade is stylesheet-order, so appending the override is unreliable —
//// the loser must be dropped).
////
//// Pure Gleam (no FFI beyond Lustre's own), dual-target (JS + BEAM); the class
//// trie is built once via `gg_cn.default()`.

import gg_cn
import gleam/list
import lustre/attribute.{type Attribute}
import lustre/vdom/vattr

/// Merge class-name fragments into one class string, resolving Tailwind
/// conflicts (last wins). `cn-*` recipe names have no conflicts so they pass
/// through untouched; raw Tailwind utilities are deduped by group. Delegates to
/// `gg_cn.cn` (clsx-style join + tailwind-merge); empty fragments are dropped.
pub fn cn(fragments: List(String)) -> String {
  gg_cn.cn(gg_cn.default(), list.map(fragments, gg_cn.Class))
}

/// The component-authoring helper: merge a component's own class string with any
/// `class` attributes the caller passed in `attrs`, and return the attribute
/// list with a single merged `class` (the caller's classes last, so they win).
///
/// This is the gg_ui analogue of shadcn's `cn(variants({ …, className }))`:
/// instead of emitting the component's class and the caller's `class` as two
/// separate attributes (which Lustre would concatenate without resolving
/// conflicts), we fold them through `cn` so an override actually overrides.
pub fn merge(
  own own: String,
  attrs attrs: List(Attribute(msg)),
) -> List(Attribute(msg)) {
  let #(class_values_rev, other_attrs_rev) =
    list.fold(attrs, #([], []), fn(acc, attr) {
      let #(classes, others) = acc
      case attr {
        vattr.Attribute(name: "class", value:, ..) -> #(
          [value, ..classes],
          others,
        )
        _ -> #(classes, [attr, ..others])
      }
    })

  let merged = cn([own, ..list.reverse(class_values_rev)])
  [attribute.class(merged), ..list.reverse(other_attrs_rev)]
}

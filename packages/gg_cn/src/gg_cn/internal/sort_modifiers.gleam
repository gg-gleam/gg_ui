//// Sort a class's variant modifiers into the canonical order so that, e.g.,
//// `c:d:e:block` and `d:c:e:block` resolve to the same conflict key.
////
//// Ported from cnfast's `src/lib/sort-modifiers.ts`:
//// - predefined modifiers sort alphabetically;
//// - arbitrary variants (`[...]`) and order-sensitive modifiers act as fences:
////   each run of plain modifiers between them is sorted independently, and the
////   fence keeps its position.

import gleam/list
import gleam/set.{type Set}
import gleam/string

pub fn sort_modifiers(
  order_sensitive: Set(String),
  modifiers: List(String),
) -> List(String) {
  let #(result_rev, segment) =
    list.fold(modifiers, #([], []), fn(acc, modifier) {
      let #(result_rev, segment) = acc
      let is_arbitrary = string.starts_with(modifier, "[")
      let is_order_sensitive = set.contains(order_sensitive, modifier)
      case is_arbitrary || is_order_sensitive {
        True -> #([modifier, ..flush(segment, result_rev)], [])
        False -> #(result_rev, [modifier, ..segment])
      }
    })

  list.reverse(flush(segment, result_rev))
}

// Sort the pending segment ascending and prepend it (reversed) onto the
// reversed result accumulator.
fn flush(segment: List(String), result_rev: List(String)) -> List(String) {
  segment
  |> list.sort(string.compare)
  |> list.fold(result_rev, fn(acc, item) { [item, ..acc] })
}

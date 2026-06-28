//// The merge engine — resolve conflicts in a joined class string, keeping the
//// last (rightmost) class per conflict group.
////
//// Ported from cnfast's `src/lib/config-utils.ts` (`computeClassDescriptor` +
//// `mergeClassList`), minus the V8-specific caches and integer interning, which
//// are JS-engine micro-optimizations irrelevant to a pure, dual-target port.
//// Conflict keys stay as plain `"{modifier}{group}"` strings compared via a set.

import gleam/list
import gleam/option.{None, Some}
import gleam/set.{type Set}
import gleam/string

import gg_cn/internal/class_map.{type ClassPart}
import gg_cn/internal/config.{type Config}
import gg_cn/internal/parse
import gg_cn/internal/sort_modifiers

const important_modifier = "!"

/// Everything the per-class analysis needs, prepared once per merge function.
pub type Engine {
  Engine(
    config: Config,
    class_map: ClassPart,
    order_sensitive: Set(String),
    postfix_lookup: Set(String),
  )
}

pub fn new(config: Config) -> Engine {
  Engine(
    config: config,
    class_map: class_map.build(config),
    order_sensitive: set.from_list(config.order_sensitive_modifiers),
    postfix_lookup: set.from_list(config.postfix_lookup_class_groups),
  )
}

/// Result of analysing one class token.
type Descriptor {
  /// Pass-through (not a Tailwind class): always kept.
  External
  /// `class_id` is this class's conflict key; `conflict_ids` the keys it clears.
  Managed(class_id: String, conflict_ids: List(String))
}

pub fn merge_class_list(engine: Engine, class_list: String) -> String {
  let tokens = split_class_list(class_list)
  case tokens {
    // A single token cannot conflict with itself.
    [single] -> single
    _ -> {
      let kept = resolve(engine, tokens)
      string.join(kept, " ")
    }
  }
}

// Right-to-left: the rightmost class per conflict group wins. A token is kept
// unless a later class already claimed one of its conflict keys. We fold over
// the reversed token list carrying the set of claimed keys, prepending kept
// tokens so the final list is back in source order.
fn resolve(engine: Engine, tokens: List(String)) -> List(String) {
  let #(kept, _claimed) =
    list.fold(list.reverse(tokens), #([], set.new()), fn(acc, token) {
      let #(kept, claimed) = acc
      case compute_descriptor(engine, token) {
        External -> #([token, ..kept], claimed)
        Managed(class_id, conflict_ids) ->
          case set.contains(claimed, class_id) {
            True -> #(kept, claimed)
            False -> {
              let claimed =
                list.fold([class_id, ..conflict_ids], claimed, fn(s, key) {
                  set.insert(s, key)
                })
              #([token, ..kept], claimed)
            }
          }
      }
    })
  kept
}

fn compute_descriptor(engine: Engine, class_name: String) -> Descriptor {
  let parsed = parse.parse_class_name(class_name)

  case parsed.maybe_postfix_modifier_position {
    Some(position) -> {
      let base_without_postfix =
        string.slice(parsed.base_class_name, 0, position)
      case
        class_map.get_class_group_id(engine.class_map, base_without_postfix)
      {
        Some(group_id) -> {
          // Retry with the postfix attached when this group opts in.
          case set.contains(engine.postfix_lookup, group_id) {
            True ->
              case
                class_map.get_class_group_id(
                  engine.class_map,
                  parsed.base_class_name,
                )
              {
                Some(group_with_postfix) if group_with_postfix != group_id ->
                  finish(engine, parsed, group_with_postfix, False)
                _ -> finish(engine, parsed, group_id, True)
              }
            False -> finish(engine, parsed, group_id, True)
          }
        }
        None ->
          // No group without the postfix; try the full base class name.
          case
            class_map.get_class_group_id(
              engine.class_map,
              parsed.base_class_name,
            )
          {
            Some(group_id) -> finish(engine, parsed, group_id, False)
            None -> External
          }
      }
    }
    None ->
      case
        class_map.get_class_group_id(engine.class_map, parsed.base_class_name)
      {
        Some(group_id) -> finish(engine, parsed, group_id, False)
        None -> External
      }
  }
}

fn finish(
  engine: Engine,
  parsed: parse.Parsed,
  group_id: String,
  has_postfix_modifier: Bool,
) -> Descriptor {
  let modifier_id = modifier_id(engine, parsed)
  let conflict_groups =
    class_map.get_conflicting_class_group_ids(
      engine.config,
      group_id,
      has_postfix_modifier,
    )
  let conflict_ids = list.map(conflict_groups, fn(g) { modifier_id <> g })
  Managed(class_id: modifier_id <> group_id, conflict_ids: conflict_ids)
}

fn modifier_id(engine: Engine, parsed: parse.Parsed) -> String {
  let variant = case parsed.modifiers {
    [] -> ""
    [single] -> single
    many ->
      sort_modifiers.sort_modifiers(engine.order_sensitive, many)
      |> string.join(":")
  }
  case parsed.has_important_modifier {
    True -> variant <> important_modifier
    False -> variant
  }
}

// Split on runs of ASCII whitespace, skipping leading/trailing runs — the
// equivalent of a `trim()` + `/\s+/` split for Tailwind's ASCII class strings.
fn split_class_list(class_list: String) -> List(String) {
  class_list
  |> string.to_graphemes
  |> list.fold(#([], ""), fn(acc, char) {
    let #(tokens_rev, current) = acc
    case is_whitespace(char) {
      True ->
        case current {
          "" -> #(tokens_rev, "")
          _ -> #([current, ..tokens_rev], "")
        }
      False -> #(tokens_rev, current <> char)
    }
  })
  |> fn(state) {
    let #(tokens_rev, current) = state
    case current {
      "" -> tokens_rev
      _ -> [current, ..tokens_rev]
    }
  }
  |> list.reverse
}

fn is_whitespace(char: String) -> Bool {
  char == " "
  || char == "\t"
  || char == "\n"
  || char == "\r"
  || char == "\f"
  || char == "\u{000B}"
}

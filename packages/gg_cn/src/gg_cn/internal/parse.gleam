//// Parse a single class name into its parts — modifiers, the `!important`
//// flag, the base class name, and the position of a possible postfix modifier
//// (`bg-red-500/50` → `/50`).
////
//// Ported from cnfast's `src/lib/parse-class-name.ts`. The bracket/paren depth
//// tracking mirrors Tailwind's `splitAtTopLevelOnly`: `:` and `/` only split
//// when not nested inside `[...]` or `(...)`.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

const important = "!"

pub type Parsed {
  Parsed(
    modifiers: List(String),
    has_important_modifier: Bool,
    base_class_name: String,
    /// Position of a possible postfix modifier *relative to* `base_class_name`.
    maybe_postfix_modifier_position: Option(Int),
  )
}

type Scan {
  Scan(
    index: Int,
    bracket: Int,
    paren: Int,
    modifier_start: Int,
    modifiers_rev: List(String),
    postfix: Option(Int),
  )
}

pub fn parse_class_name(class_name: String) -> Parsed {
  let chars = string.to_graphemes(class_name)
  let final =
    list.fold(
      chars,
      Scan(
        index: 0,
        bracket: 0,
        paren: 0,
        modifier_start: 0,
        modifiers_rev: [],
        postfix: None,
      ),
      fn(state, char) { step(class_name, state, char) },
    )

  let total = list.length(chars)
  let modifiers = list.reverse(final.modifiers_rev)

  let base_with_important = case modifiers {
    [] -> class_name
    _ ->
      string.slice(
        class_name,
        final.modifier_start,
        total - final.modifier_start,
      )
  }

  let #(base_class_name, has_important_modifier) =
    resolve_important(base_with_important)

  let maybe_postfix = case final.postfix {
    Some(position) ->
      case position > final.modifier_start {
        True -> Some(position - final.modifier_start)
        False -> None
      }
    None -> None
  }

  Parsed(
    modifiers: modifiers,
    has_important_modifier: has_important_modifier,
    base_class_name: base_class_name,
    maybe_postfix_modifier_position: maybe_postfix,
  )
}

fn step(class_name: String, state: Scan, char: String) -> Scan {
  let index = state.index
  let top_level = state.bracket == 0 && state.paren == 0

  case top_level, char {
    True, ":" ->
      Scan(
        ..state,
        index: index + 1,
        modifiers_rev: [
          string.slice(
            class_name,
            state.modifier_start,
            index - state.modifier_start,
          ),
          ..state.modifiers_rev
        ],
        modifier_start: index + 1,
      )
    True, "/" -> Scan(..state, index: index + 1, postfix: Some(index))
    _, "[" -> Scan(..state, index: index + 1, bracket: state.bracket + 1)
    _, "]" -> Scan(..state, index: index + 1, bracket: state.bracket - 1)
    _, "(" -> Scan(..state, index: index + 1, paren: state.paren + 1)
    _, ")" -> Scan(..state, index: index + 1, paren: state.paren - 1)
    _, _ -> Scan(..state, index: index + 1)
  }
}

fn resolve_important(base_with_important: String) -> #(String, Bool) {
  case string.ends_with(base_with_important, important) {
    True -> #(string.drop_end(base_with_important, 1), True)
    False ->
      // Tailwind CSS v3 legacy: important at the start (`!font-bold`).
      case string.starts_with(base_with_important, important) {
        True -> #(string.drop_start(base_with_important, 1), True)
        False -> #(base_with_important, False)
      }
  }
}

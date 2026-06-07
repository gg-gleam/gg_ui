//// Naming rules shared by the generator and (later) the transformer, so both
//// derive identical module/function/shard names from an upstream icon name.

import gleam/list
import gleam/string

const lower = "abcdefghijklmnopqrstuvwxyz"

const digits = "0123456789"

/// Upstream kebab/space name → snake_case identifier body: lowercased, `-`/`.`/
/// space → `_`, and any remaining non-`[a-z0-9_]` dropped. (`"chevron-down"` →
/// `"chevron_down"`.)
pub fn snake_case(name: String) -> String {
  name
  |> string.lowercase
  |> string.replace("-", "_")
  |> string.replace(".", "_")
  |> string.replace(" ", "_")
  |> string.to_graphemes
  |> keep_ident([])
}

fn keep_ident(graphemes: List(String), acc: List(String)) -> String {
  case graphemes {
    [] -> acc |> list_reverse_join
    [g, ..rest] ->
      case g == "_" || contains_char(lower, g) || contains_char(digits, g) {
        True -> keep_ident(rest, [g, ..acc])
        False -> keep_ident(rest, acc)
      }
  }
}

/// The shard a snake name belongs to: its first letter, or `"0"` for a
/// digit-leading or otherwise non-`a–z` name.
pub fn shard(snake: String) -> String {
  let first = string.slice(snake, 0, 1)
  case first != "" && contains_char(lower, first) {
    True -> first
    False -> "0"
  }
}

/// Gleam's reserved words. A snake name that lands on one (`import`, `type`,
/// `macro`, …) can't be a function name, so `fn_name` suffixes it with `_`.
const reserved = [
  "as", "assert", "auto", "case", "const", "delegate", "derive", "echo", "else",
  "fn", "if", "implement", "import", "let", "macro", "opaque", "panic", "pub",
  "test", "todo", "type", "use",
]

/// The Gleam function name for a snake name. Two collisions are escaped:
/// identifiers can't start with a digit, so a digit-leading name is prefixed
/// with `n` (`"24_hours"` → `"n24_hours"`; shard stays `"0"`); and a name that
/// equals a reserved word is suffixed with `_` (`"import"` → `"import_"`). Both
/// the generator and the transformer derive call names through here, so they
/// agree. The manifest still keys on the unescaped snake name (the icon's
/// identity).
pub fn fn_name(snake: String) -> String {
  let first = string.slice(snake, 0, 1)
  case first != "" && contains_char(digits, first) {
    True -> "n" <> snake
    False ->
      case list.contains(reserved, snake) {
        True -> snake <> "_"
        False -> snake
      }
  }
}

fn contains_char(set: String, char: String) -> Bool {
  case char {
    "" -> False
    _ -> string.contains(set, char)
  }
}

fn list_reverse_join(chars: List(String)) -> String {
  chars
  |> reverse([])
  |> string.concat
}

fn reverse(xs: List(String), acc: List(String)) -> List(String) {
  case xs {
    [] -> acc
    [x, ..rest] -> reverse(rest, [x, ..acc])
  }
}

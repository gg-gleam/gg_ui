//// Class-part validators — the predicates that decide whether an *arbitrary*
//// (or otherwise dynamic) class part belongs to a given Tailwind class group.
////
//// Ported from cnfast's `src/lib/validators.ts`. The regexes are compiled once
//// into a `Regexes` record (see `compile`) and threaded into the config so a
//// merge never recompiles. Pure Gleam — `gleam_regexp` compiles to the host
//// regex engine on both targets, and the patterns here are plain ASCII.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp.{type Regexp}
import gleam/string

/// All regexes the validators need, compiled once.
pub type Regexes {
  Regexes(
    arbitrary_value: Regexp,
    arbitrary_variable: Regexp,
    fraction: Regexp,
    tshirt: Regexp,
    length_unit: Regexp,
    color_function: Regexp,
    shadow: Regexp,
    image: Regexp,
    number_decimal: Regexp,
    number_hex: Regexp,
    number_oct: Regexp,
    number_bin: Regexp,
  )
}

fn ci(pattern: String) -> Regexp {
  let assert Ok(re) =
    regexp.compile(
      pattern,
      regexp.Options(case_insensitive: True, multi_line: False),
    )
  re
}

fn cs(pattern: String) -> Regexp {
  let assert Ok(re) =
    regexp.compile(
      pattern,
      regexp.Options(case_insensitive: False, multi_line: False),
    )
  re
}

pub fn compile() -> Regexes {
  Regexes(
    arbitrary_value: ci("^\\[(?:(\\w[\\w-]*):)?(.+)\\]$"),
    arbitrary_variable: ci("^\\((?:(\\w[\\w-]*):)?(.+)\\)$"),
    fraction: cs("^\\d+(?:\\.\\d+)?\\/\\d+(?:\\.\\d+)?$"),
    tshirt: cs("^(\\d+(\\.\\d+)?)?(xs|sm|md|lg|xl)$"),
    length_unit: cs(
      "\\d+(%|px|r?em|[sdl]?v([hwib]|min|max)|pt|pc|in|cm|mm|cap|ch|ex|r?lh|cq(w|h|i|b|min|max))|\\b(calc|min|max|clamp)\\(.+\\)|^0$",
    ),
    color_function: cs("^(rgba?|hsla?|hwb|(ok)?(lab|lch)|color-mix)\\(.+\\)$"),
    shadow: cs(
      "^(inset_)?-?((\\d+)?\\.?(\\d+)[a-z]+|0)_-?((\\d+)?\\.?(\\d+)[a-z]+|0)",
    ),
    image: cs(
      "^(url|image|image-set|cross-fade|element|(repeating-)?(linear|radial|conic)-gradient)\\(.+\\)$",
    ),
    number_decimal: cs("^[+-]?(\\d+(\\.\\d*)?|\\.\\d+)([eE][+-]?\\d+)?$"),
    number_hex: cs("^0[xX][0-9a-fA-F]+$"),
    number_oct: cs("^0[oO][0-7]+$"),
    number_bin: cs("^0[bB][01]+$"),
  )
}

// --- submatch helpers ---------------------------------------------------------

fn first_submatches(
  re: Regexp,
  value: String,
) -> Result(List(Option(String)), Nil) {
  case regexp.scan(re, value) {
    [match, ..] -> Ok(match.submatches)
    [] -> Error(Nil)
  }
}

fn submatch(subs: List(Option(String)), index: Int) -> Option(String) {
  case list.drop(subs, index) {
    [first, ..] -> first
    [] -> None
  }
}

// --- number predicates --------------------------------------------------------

pub fn is_number(rx: Regexes, value: String) -> Bool {
  let v = string.trim(value)
  v != ""
  && {
    regexp.check(rx.number_decimal, v)
    || regexp.check(rx.number_hex, v)
    || regexp.check(rx.number_oct, v)
    || regexp.check(rx.number_bin, v)
  }
}

pub fn is_integer(rx: Regexes, value: String) -> Bool {
  let v = string.trim(value)
  is_number(rx, v) && integral(rx, v)
}

fn integral(rx: Regexes, v: String) -> Bool {
  case
    regexp.check(rx.number_hex, v)
    || regexp.check(rx.number_oct, v)
    || regexp.check(rx.number_bin, v)
  {
    True -> True
    False -> {
      let unsigned = case string.starts_with(v, "+") {
        True -> string.drop_start(v, 1)
        False -> v
      }
      case int.parse(unsigned) {
        Ok(_) -> True
        Error(_) ->
          case float.parse(unsigned) {
            Ok(f) -> float.floor(f) == f
            Error(_) -> False
          }
      }
    }
  }
}

pub fn is_percent(rx: Regexes, value: String) -> Bool {
  string.ends_with(value, "%") && is_number(rx, string.drop_end(value, 1))
}

pub fn is_fraction(rx: Regexes, value: String) -> Bool {
  regexp.check(rx.fraction, value)
}

pub fn is_tshirt_size(rx: Regexes, value: String) -> Bool {
  regexp.check(rx.tshirt, value)
}

pub fn is_any(_value: String) -> Bool {
  True
}

pub fn is_any_non_arbitrary(rx: Regexes, value: String) -> Bool {
  !is_arbitrary_value(rx, value) && !is_arbitrary_variable(rx, value)
}

// --- arbitrary value / variable predicates ------------------------------------

pub fn is_arbitrary_value(rx: Regexes, value: String) -> Bool {
  regexp.check(rx.arbitrary_value, value)
}

pub fn is_arbitrary_variable(rx: Regexes, value: String) -> Bool {
  regexp.check(rx.arbitrary_variable, value)
}

fn is_length_only(rx: Regexes, value: String) -> Bool {
  // The color-function guard mirrors the upstream comment: color functions can
  // contain percentages that would otherwise read as lengths (`hsl(0 0% 0%)`).
  regexp.check(rx.length_unit, value) && !regexp.check(rx.color_function, value)
}

fn is_shadow(rx: Regexes, value: String) -> Bool {
  regexp.check(rx.shadow, value)
}

fn is_image(rx: Regexes, value: String) -> Bool {
  regexp.check(rx.image, value)
}

fn never(_value: String) -> Bool {
  False
}

fn get_is_arbitrary_value(
  rx: Regexes,
  value: String,
  test_label: fn(String) -> Bool,
  test_value: fn(String) -> Bool,
) -> Bool {
  case first_submatches(rx.arbitrary_value, value) {
    Ok(subs) ->
      case submatch(subs, 0) {
        Some(label) -> test_label(label)
        None ->
          case submatch(subs, 1) {
            Some(inner) -> test_value(inner)
            None -> False
          }
      }
    Error(_) -> False
  }
}

fn get_is_arbitrary_variable(
  rx: Regexes,
  value: String,
  test_label: fn(String) -> Bool,
  should_match_no_label: Bool,
) -> Bool {
  case first_submatches(rx.arbitrary_variable, value) {
    Ok(subs) ->
      case submatch(subs, 0) {
        Some(label) -> test_label(label)
        None -> should_match_no_label
      }
    Error(_) -> False
  }
}

pub fn is_arbitrary_size(rx: Regexes, value: String) -> Bool {
  get_is_arbitrary_value(rx, value, is_label_size, never)
}

pub fn is_arbitrary_length(rx: Regexes, value: String) -> Bool {
  get_is_arbitrary_value(rx, value, is_label_length, fn(v) {
    is_length_only(rx, v)
  })
}

pub fn is_arbitrary_number(rx: Regexes, value: String) -> Bool {
  get_is_arbitrary_value(rx, value, is_label_number, fn(v) { is_number(rx, v) })
}

pub fn is_arbitrary_weight(rx: Regexes, value: String) -> Bool {
  get_is_arbitrary_value(rx, value, is_label_weight, is_any)
}

pub fn is_arbitrary_family_name(rx: Regexes, value: String) -> Bool {
  get_is_arbitrary_value(rx, value, is_label_family_name, never)
}

pub fn is_arbitrary_position(rx: Regexes, value: String) -> Bool {
  get_is_arbitrary_value(rx, value, is_label_position, never)
}

pub fn is_arbitrary_image(rx: Regexes, value: String) -> Bool {
  get_is_arbitrary_value(rx, value, is_label_image, fn(v) { is_image(rx, v) })
}

pub fn is_arbitrary_shadow(rx: Regexes, value: String) -> Bool {
  get_is_arbitrary_value(rx, value, is_label_shadow, fn(v) { is_shadow(rx, v) })
}

pub fn is_arbitrary_variable_length(rx: Regexes, value: String) -> Bool {
  get_is_arbitrary_variable(rx, value, is_label_length, False)
}

pub fn is_arbitrary_variable_family_name(rx: Regexes, value: String) -> Bool {
  get_is_arbitrary_variable(rx, value, is_label_family_name, False)
}

pub fn is_arbitrary_variable_position(rx: Regexes, value: String) -> Bool {
  get_is_arbitrary_variable(rx, value, is_label_position, False)
}

pub fn is_arbitrary_variable_size(rx: Regexes, value: String) -> Bool {
  get_is_arbitrary_variable(rx, value, is_label_size, False)
}

pub fn is_arbitrary_variable_image(rx: Regexes, value: String) -> Bool {
  get_is_arbitrary_variable(rx, value, is_label_image, False)
}

pub fn is_arbitrary_variable_shadow(rx: Regexes, value: String) -> Bool {
  get_is_arbitrary_variable(rx, value, is_label_shadow, True)
}

pub fn is_arbitrary_variable_weight(rx: Regexes, value: String) -> Bool {
  get_is_arbitrary_variable(rx, value, is_label_weight, True)
}

// --- label predicates ---------------------------------------------------------

fn is_label_position(label: String) -> Bool {
  label == "position" || label == "percentage"
}

fn is_label_image(label: String) -> Bool {
  label == "image" || label == "url"
}

fn is_label_size(label: String) -> Bool {
  label == "length" || label == "size" || label == "bg-size"
}

fn is_label_length(label: String) -> Bool {
  label == "length"
}

fn is_label_number(label: String) -> Bool {
  label == "number"
}

fn is_label_family_name(label: String) -> Bool {
  label == "family-name"
}

fn is_label_weight(label: String) -> Bool {
  label == "number" || label == "weight"
}

fn is_label_shadow(label: String) -> Bool {
  label == "shadow"
}

// --- named container query ----------------------------------------------------

pub fn is_named_container_query(value: String) -> Bool {
  case string.starts_with(value, "@container") {
    False -> False
    True -> {
      let rest = string.drop_start(value, 10)
      let n = string.length(rest)
      let char0 = string.slice(rest, 0, 1)
      let char1 = string.slice(rest, 1, 1)
      { char0 == "/" && n > 1 }
      || { char1 == "s" && n > 6 && string.starts_with(rest, "-size/") }
      || { char1 == "n" && n > 8 && string.starts_with(rest, "-normal/") }
    }
  }
}

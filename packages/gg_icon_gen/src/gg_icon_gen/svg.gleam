//// A tolerant, dependency-free SVG → lustre `svg.*` emitter. Icon SVGs are a
//// small, regular subset (path/circle/rect/line/ellipse/polygon/polyline, the
//// odd `g`), so we parse them ourselves rather than pull `html_lustre_converter`
//// (which is JS-only and needs a browser `DOMParser`, unusable in a CLI). Pure
//// Gleam → runs on either target, fully testable.

import gleam/list
import gleam/string

/// A parsed SVG element. Text/comments are ignored — icons are element-only.
pub type Node {
  Element(tag: String, attrs: List(#(String, String)), children: List(Node))
}

const containers = ["g", "defs", "svg", "text", "mask", "clip_path"]

// --- Parsing -----------------------------------------------------------------

/// Strip the wrapping `<svg …>…</svg>` and return the inner markup. The opening
/// tag's attributes (viewBox/width/stroke/…) are dropped — the generator re-bakes
/// them via `gg_icon.svg`. Any leading XML prolog/comment (e.g. lucide-static's
/// `<!-- @license … -->`) is skipped by locating the `<svg` tag itself rather
/// than the first `>`.
pub fn extract_inner(svg_text: String) -> String {
  case string.split_once(svg_text, "<svg") {
    Error(_) -> ""
    Ok(#(_prolog, after_svg)) ->
      // Drop the rest of the opening tag (its attributes), then take the body.
      case string.split_once(after_svg, ">") {
        Error(_) -> ""
        Ok(#(_open_tag_attrs, rest)) ->
          case string.split_once(rest, "</svg>") {
            Ok(#(inner, _)) -> string.trim(inner)
            Error(_) -> string.trim(rest)
          }
      }
  }
}

/// Parse a run of sibling elements (e.g. the output of `extract_inner`).
pub fn parse(inner: String) -> List(Node) {
  let #(nodes, _rest) = parse_siblings(normalize_ws(inner), [])
  nodes
}

fn normalize_ws(s: String) -> String {
  s
  |> string.replace("\n", " ")
  |> string.replace("\t", " ")
  |> string.replace("\r", " ")
}

fn parse_siblings(input: String, acc: List(Node)) -> #(List(Node), String) {
  let input = drop_until_lt(input)
  case input {
    "" -> #(list.reverse(acc), "")
    _ ->
      case string.starts_with(input, "</") {
        True -> #(list.reverse(acc), input)
        False ->
          case skip_non_element(input) {
            Ok(rest) -> parse_siblings(rest, acc)
            Error(_) -> {
              let #(node, rest) = parse_element(input)
              parse_siblings(rest, [node, ..acc])
            }
          }
      }
  }
}

fn drop_until_lt(s: String) -> String {
  case string.split_once(s, "<") {
    Ok(#(_before, after)) -> "<" <> after
    Error(_) -> ""
  }
}

fn skip_non_element(input: String) -> Result(String, Nil) {
  case string.starts_with(input, "<!--") {
    True ->
      case string.split_once(input, "-->") {
        Ok(#(_, rest)) -> Ok(rest)
        Error(_) -> Ok("")
      }
    False ->
      case string.starts_with(input, "<!") || string.starts_with(input, "<?") {
        True ->
          case string.split_once(input, ">") {
            Ok(#(_, rest)) -> Ok(rest)
            Error(_) -> Ok("")
          }
        False -> Error(Nil)
      }
  }
}

fn parse_element(input: String) -> #(Node, String) {
  case string.split_once(input, ">") {
    Error(_) -> #(Element("", [], []), "")
    Ok(#(start_tag, after)) -> {
      let body = string.drop_start(start_tag, 1)
      let self_closing = string.ends_with(body, "/")
      let body = case self_closing {
        True -> string.drop_end(body, 1)
        False -> body
      }
      let #(tag, attrs) = parse_tag(body)
      case self_closing {
        True -> #(Element(tag, attrs, []), after)
        False -> {
          let #(children, rest) = parse_siblings(after, [])
          #(Element(tag, attrs, children), consume_closing(rest))
        }
      }
    }
  }
}

fn parse_tag(body: String) -> #(String, List(#(String, String))) {
  case string.split_once(string.trim(body), " ") {
    Error(_) -> #(string.trim(body), [])
    Ok(#(name, rest)) -> #(name, parse_attrs(rest))
  }
}

fn consume_closing(rest: String) -> String {
  case string.split_once(rest, ">") {
    Ok(#(_, after)) -> after
    Error(_) -> ""
  }
}

fn parse_attrs(s: String) -> List(#(String, String)) {
  case string.trim(s) {
    "" -> []
    trimmed ->
      case string.split_once(trimmed, "=") {
        Error(_) -> bool_attrs(trimmed)
        Ok(#(key_part, after_eq)) -> {
          let #(leading, key) = split_last_token(key_part)
          let #(value, rest) = read_quoted(string.trim_start(after_eq))
          list.append(bool_attrs_of(leading), [
            #(key, value),
            ..parse_attrs(rest)
          ])
        }
      }
  }
}

fn bool_attrs(s: String) -> List(#(String, String)) {
  s
  |> string.split(" ")
  |> list.filter(fn(t) { t != "" })
  |> list.map(fn(k) { #(k, "") })
}

fn bool_attrs_of(tokens: List(String)) -> List(#(String, String)) {
  list.map(tokens, fn(k) { #(k, "") })
}

fn split_last_token(s: String) -> #(List(String), String) {
  let tokens =
    s
    |> string.trim
    |> string.split(" ")
    |> list.filter(fn(t) { t != "" })
  case list.reverse(tokens) {
    [] -> #([], "")
    [last, ..rest] -> #(list.reverse(rest), last)
  }
}

fn read_quoted(s: String) -> #(String, String) {
  case string.pop_grapheme(s) {
    Ok(#(q, rest)) if q == "\"" || q == "'" ->
      case string.split_once(rest, q) {
        Ok(#(val, after)) -> #(val, after)
        Error(_) -> #(rest, "")
      }
    _ ->
      case string.split_once(s, " ") {
        Ok(#(val, after)) -> #(val, after)
        Error(_) -> #(s, "")
      }
  }
}

// --- Emitting ----------------------------------------------------------------

/// Emit a comma-separated list of lustre `svg.*` calls for the given nodes —
/// the `children:` argument of a `gg_icon.svg(...)` call.
pub fn emit_children(children: List(Node)) -> String {
  children
  |> list.map(emit_node)
  |> string.join(", ")
}

fn emit_node(node: Node) -> String {
  let Element(tag, attrs, children) = node
  let lustre = lustre_tag(tag)
  case list.contains(containers, tag) {
    True ->
      "svg."
      <> lustre
      <> "("
      <> emit_attrs(attrs)
      <> ", ["
      <> emit_children(children)
      <> "])"
    False -> "svg." <> lustre <> "(" <> emit_attrs(attrs) <> ")"
  }
}

fn emit_attrs(attrs: List(#(String, String))) -> String {
  "["
  <> {
    attrs
    |> list.map(fn(a) {
      "attribute.attribute(\"" <> a.0 <> "\", \"" <> escape(a.1) <> "\")"
    })
    |> string.join(", ")
  }
  <> "]"
}

fn lustre_tag(tag: String) -> String {
  case tag {
    "use" -> "use_"
    "clip_path" | "clipPath" -> "clip_path"
    _ -> tag
  }
}

fn escape(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
}

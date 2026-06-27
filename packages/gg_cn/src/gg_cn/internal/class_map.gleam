//// The class-name trie and its lookups.
////
//// Ported from cnfast's `src/lib/class-group-utils.ts`. `build` turns the
//// config's class groups (and theme scales) into a prefix trie keyed on the
//// `-`-separated parts of a class name; `get_class_group_id` walks it, and
//// `get_conflicting_class_group_ids` reads the conflict tables.

import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

import gg_cn/internal/config.{type ClassDef, type Config, Lit, Obj, Theme, Val}

const arbitrary_property_prefix = "arbitrary.."

pub type ClassPart {
  ClassPart(
    next: Dict(String, ClassPart),
    validators: List(#(String, fn(String) -> Bool)),
    group_id: Option(String),
  )
}

fn empty() -> ClassPart {
  ClassPart(next: dict.new(), validators: [], group_id: None)
}

// --- building -----------------------------------------------------------------

pub fn build(cfg: Config) -> ClassPart {
  list.fold(cfg.class_groups, empty(), fn(part, group) {
    let #(group_id, defs) = group
    process_defs(defs, part, group_id, cfg.theme)
  })
}

fn process_defs(
  defs: List(ClassDef),
  part: ClassPart,
  group_id: String,
  theme: Dict(String, List(ClassDef)),
) -> ClassPart {
  list.fold(defs, part, fn(acc, def) { process_def(def, acc, group_id, theme) })
}

fn process_def(
  def: ClassDef,
  part: ClassPart,
  group_id: String,
  theme: Dict(String, List(ClassDef)),
) -> ClassPart {
  case def {
    Lit("") -> ClassPart(..part, group_id: Some(group_id))
    Lit(literal) ->
      update_at_path(part, string.split(literal, "-"), fn(node) {
        ClassPart(..node, group_id: Some(group_id))
      })
    Theme(key) -> {
      let resolved = dict.get(theme, key) |> result.unwrap([])
      process_defs(resolved, part, group_id, theme)
    }
    Val(validator) ->
      ClassPart(
        ..part,
        validators: list.append(part.validators, [#(group_id, validator)]),
      )
    Obj(entries) ->
      list.fold(entries, part, fn(acc, entry) {
        let #(key, child_defs) = entry
        update_at_path(acc, string.split(key, "-"), fn(node) {
          process_defs(child_defs, node, group_id, theme)
        })
      })
  }
}

fn update_at_path(
  part: ClassPart,
  path: List(String),
  update: fn(ClassPart) -> ClassPart,
) -> ClassPart {
  case path {
    [] -> update(part)
    [head, ..tail] -> {
      let child = case dict.get(part.next, head) {
        Ok(node) -> node
        Error(_) -> empty()
      }
      let updated = update_at_path(child, tail, update)
      ClassPart(..part, next: dict.insert(part.next, head, updated))
    }
  }
}

// --- lookups ------------------------------------------------------------------

pub fn get_class_group_id(
  class_map: ClassPart,
  class_name: String,
) -> Option(String) {
  case
    string.starts_with(class_name, "[") && string.ends_with(class_name, "]")
  {
    True -> arbitrary_property_group_id(class_name)
    False -> {
      let parts = string.split(class_name, "-")
      // Negative values (`-inset-1`) produce a leading empty part — skip it.
      let parts = case parts {
        ["", _, ..] -> list.drop(parts, 1)
        _ -> parts
      }
      get_group_recursive(parts, class_map)
    }
  }
}

fn arbitrary_property_group_id(class_name: String) -> Option(String) {
  let content = string.slice(class_name, 1, string.length(class_name) - 2)
  case string.split_once(content, ":") {
    Ok(#(property, _)) ->
      case property {
        "" -> None
        _ -> Some(arbitrary_property_prefix <> property)
      }
    Error(_) -> None
  }
}

fn get_group_recursive(parts: List(String), part: ClassPart) -> Option(String) {
  case parts {
    [] -> part.group_id
    [head, ..tail] -> {
      let from_next = case dict.get(part.next, head) {
        Ok(child) -> get_group_recursive(tail, child)
        Error(_) -> None
      }
      case from_next {
        Some(_) -> from_next
        None ->
          case part.validators {
            [] -> None
            validators -> find_validator(validators, string.join(parts, "-"))
          }
      }
    }
  }
}

fn find_validator(
  validators: List(#(String, fn(String) -> Bool)),
  class_rest: String,
) -> Option(String) {
  case validators {
    [] -> None
    [#(group_id, validator), ..rest] ->
      case validator(class_rest) {
        True -> Some(group_id)
        False -> find_validator(rest, class_rest)
      }
  }
}

pub fn get_conflicting_class_group_ids(
  cfg: Config,
  class_group_id: String,
  has_postfix_modifier: Bool,
) -> List(String) {
  case has_postfix_modifier {
    True -> {
      let base = dict.get(cfg.conflicting_class_groups, class_group_id)
      case dict.get(cfg.conflicting_class_group_modifiers, class_group_id) {
        Ok(modifier_conflicts) ->
          case base {
            Ok(base_conflicts) ->
              list.append(base_conflicts, modifier_conflicts)
            Error(_) -> modifier_conflicts
          }
        Error(_) -> result.unwrap(base, [])
      }
    }
    False ->
      result.unwrap(dict.get(cfg.conflicting_class_groups, class_group_id), [])
  }
}

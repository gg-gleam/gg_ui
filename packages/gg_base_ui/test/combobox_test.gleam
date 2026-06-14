import gg_base_ui/combobox/combobox
import gleam/list
import gleam/option.{None, Some}

// A small fixture list. Values are ints so selection equality is easy to assert.
fn fruits() -> List(combobox.Item(Int)) {
  [
    combobox.Item(value: 1, label: "Apple", disabled: False),
    combobox.Item(value: 2, label: "Apricot", disabled: False),
    combobox.Item(value: 3, label: "Banana", disabled: False),
    combobox.Item(value: 4, label: "Cherry", disabled: False),
  ]
}

fn model() -> combobox.Model(Int) {
  combobox.init(items: fruits(), config: combobox.config())
}

// --- filtering -----------------------------------------------------------

pub fn matches_empty_query_test() {
  assert combobox.matches(label: "Apple", query: "")
}

pub fn matches_case_insensitive_substring_test() {
  assert combobox.matches(label: "Apple", query: "ppl")
  assert combobox.matches(label: "Apple", query: "APPLE")
  assert combobox.matches(label: "Banana", query: "nan")
}

pub fn matches_non_match_test() {
  assert !combobox.matches(label: "Apple", query: "xyz")
}

pub fn visible_keeps_original_indices_test() {
  let m = combobox.set_query(model(), "ap")
  // "Apple" (idx 0) and "Apricot" (idx 1) match; indices preserved.
  assert combobox.visible(m) |> list.map(fn(p) { p.0 }) == [0, 1]
}

pub fn visible_empty_query_is_all_test() {
  assert combobox.visible_count(model()) == 4
}

pub fn is_empty_test() {
  assert combobox.is_empty(combobox.set_query(model(), "zzz"))
  assert !combobox.is_empty(combobox.set_query(model(), "a"))
}

// --- navigation ----------------------------------------------------------

pub fn navigate_empty_list_test() {
  assert combobox.navigate(
      active: None,
      nav: combobox.Next,
      count: 0,
      loop: True,
    )
    == None
}

pub fn navigate_from_none_seeds_ends_test() {
  assert combobox.navigate(
      active: None,
      nav: combobox.Next,
      count: 3,
      loop: True,
    )
    == Some(0)
  assert combobox.navigate(
      active: None,
      nav: combobox.Previous,
      count: 3,
      loop: True,
    )
    == Some(2)
}

pub fn navigate_first_last_test() {
  assert combobox.navigate(
      active: Some(2),
      nav: combobox.First,
      count: 4,
      loop: False,
    )
    == Some(0)
  assert combobox.navigate(
      active: Some(1),
      nav: combobox.Last,
      count: 4,
      loop: False,
    )
    == Some(3)
}

pub fn navigate_next_loops_test() {
  assert combobox.navigate(
      active: Some(2),
      nav: combobox.Next,
      count: 3,
      loop: True,
    )
    == Some(0)
}

pub fn navigate_next_clamps_without_loop_test() {
  assert combobox.navigate(
      active: Some(2),
      nav: combobox.Next,
      count: 3,
      loop: False,
    )
    == Some(2)
}

pub fn navigate_previous_loops_test() {
  assert combobox.navigate(
      active: Some(0),
      nav: combobox.Previous,
      count: 3,
      loop: True,
    )
    == Some(2)
}

pub fn navigate_previous_clamps_without_loop_test() {
  assert combobox.navigate(
      active: Some(0),
      nav: combobox.Previous,
      count: 3,
      loop: False,
    )
    == Some(0)
}

// --- transitions ---------------------------------------------------------

pub fn set_query_opens_and_sets_input_test() {
  let m = combobox.set_query(model(), "ap")
  assert m.open
  assert m.query == "ap"
  assert m.input_value == "ap"
}

pub fn set_query_no_auto_highlight_by_default_test() {
  assert { combobox.set_query(model(), "ap") }.active_index == None
}

pub fn set_query_auto_highlight_first_test() {
  let m =
    combobox.init(
      items: fruits(),
      config: combobox.Config(loop: True, auto_highlight: True),
    )
  assert { combobox.set_query(m, "ap") }.active_index == Some(0)
}

pub fn move_highlights_visible_test() {
  let m = combobox.set_query(model(), "ap") |> combobox.move(combobox.Next)
  assert m.active_index == Some(0)
  assert combobox.active_item(m) == Some(combobox.Item(1, "Apple", False))
}

pub fn select_active_returns_value_and_closes_test() {
  // Type "ap", highlight the second match (Apricot), select it.
  let m =
    combobox.set_query(model(), "ap")
    |> combobox.move(combobox.Next)
    |> combobox.move(combobox.Next)
  let #(next, chosen) = combobox.select_active(m)
  assert chosen == Some(2)
  assert next.selected == Some(2)
  assert next.input_value == "Apricot"
  assert !next.open
  assert next.query == ""
}

pub fn select_active_none_when_no_highlight_test() {
  let #(next, chosen) =
    combobox.select_active(combobox.set_query(model(), "ap"))
  assert chosen == None
  assert next.selected == None
}

pub fn select_specific_item_test() {
  let m =
    combobox.select(combobox.open(model()), combobox.Item(3, "Banana", False))
  assert m.selected == Some(3)
  assert m.input_value == "Banana"
  assert !m.open
  assert combobox.is_selected(m, 3)
  assert !combobox.is_selected(m, 1)
}

pub fn close_drops_highlight_keeps_selection_test() {
  let m =
    combobox.select(combobox.open(model()), combobox.Item(1, "Apple", False))
    |> combobox.open
    |> combobox.move(combobox.First)
    |> combobox.close
  assert !m.open
  assert m.active_index == None
  assert m.selected == Some(1)
}

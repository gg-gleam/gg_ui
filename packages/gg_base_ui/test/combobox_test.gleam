import birdie
import gg_base_ui/combobox/combobox
import gg_base_ui/positioning/positioning
import gleam/list
import gleam/option.{None, Some}
import lustre/element
import lustre/element/html

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
      config: combobox.Config(
        loop: True,
        auto_highlight: True,
        mode: combobox.Single,
        filter: combobox.Client,
        search_debounce: 0,
      ),
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
  assert next.selected == [2]
  assert next.input_value == "Apricot"
  assert !next.open
  assert next.query == ""
}

pub fn select_active_none_when_no_highlight_test() {
  let #(next, chosen) =
    combobox.select_active(combobox.set_query(model(), "ap"))
  assert chosen == None
  assert next.selected == []
}

pub fn select_specific_item_test() {
  let m =
    combobox.select(combobox.open(model()), combobox.Item(3, "Banana", False))
  assert m.selected == [3]
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
  assert m.selected == [1]
}

// =========================================================================
// Effectful shell — update transitions + ARIA render contracts
// =========================================================================

fn anatomy() -> combobox.Anatomy {
  combobox.anatomy_with_id("cb")
}

// --- update transitions (model half of #(Model, Effect)) -----------------

pub fn update_input_changed_filters_and_opens_test() {
  let #(m, _) = combobox.update(anatomy(), model(), combobox.InputChanged("ap"))
  assert m.open
  assert m.query == "ap"
  assert combobox.visible_count(m) == 2
}

pub fn update_move_next_from_closed_opens_and_highlights_test() {
  let #(m, _) = combobox.update(anatomy(), model(), combobox.MoveNext)
  assert m.open
  assert m.active_index == Some(0)
}

pub fn update_move_next_twice_advances_test() {
  let #(m1, _) = combobox.update(anatomy(), model(), combobox.MoveNext)
  let #(m2, _) = combobox.update(anatomy(), m1, combobox.MoveNext)
  assert m2.active_index == Some(1)
}

pub fn update_choose_active_selects_and_closes_test() {
  let m = combobox.move(combobox.open(model()), combobox.Next)
  let #(next, _) = combobox.update(anatomy(), m, combobox.ChooseActive)
  assert next.selected == [1]
  assert next.input_value == "Apple"
  assert !next.open
}

pub fn update_option_chosen_selects_visible_position_test() {
  // "ap" → [Apple(0), Apricot(1)]; choose visible position 1 (Apricot).
  let m = combobox.set_query(model(), "ap")
  let #(next, _) = combobox.update(anatomy(), m, combobox.OptionChosen(1))
  assert next.selected == [2]
  assert next.input_value == "Apricot"
  assert !next.open
}

pub fn update_option_highlighted_sets_active_test() {
  let #(m, _) =
    combobox.update(
      anatomy(),
      combobox.open(model()),
      combobox.OptionHighlighted(2),
    )
  assert m.active_index == Some(2)
}

pub fn update_dismissed_closes_test() {
  let m = combobox.move(combobox.open(model()), combobox.First)
  let #(next, _) = combobox.update(anatomy(), m, combobox.Dismissed)
  assert !next.open
  assert next.active_index == None
}

pub fn update_list_toggled_syncs_open_test() {
  let #(closed, _) =
    combobox.update(
      anatomy(),
      combobox.open(model()),
      combobox.ListToggled(False),
    )
  assert !closed.open
  let #(opened, _) =
    combobox.update(anatomy(), model(), combobox.ListToggled(True))
  assert opened.open
}

// --- ARIA render contracts (birdie) --------------------------------------

fn placement() -> positioning.Placement {
  positioning.Placement(side: positioning.Bottom, align: positioning.Start)
}

pub fn render_input_closed_test() {
  combobox.input(anatomy(), model(), [])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_base_ui combobox input — closed")
}

pub fn render_input_open_active_test() {
  let m =
    combobox.move(
      combobox.open(combobox.set_query(model(), "a")),
      combobox.Next,
    )
  combobox.input(anatomy(), m, [])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_base_ui combobox input — open + active descendant")
}

pub fn render_popup_test() {
  combobox.popup(anatomy(), placement(), 4, "18rem", [], [
    combobox.list(anatomy(), combobox.Single, [], []),
  ])
  |> element.to_readable_string
  |> birdie.snap(
    title: "gg_base_ui combobox popup — native popover wrapping a listbox",
  )
}

pub fn render_option_selected_active_test() {
  // Apple selected, then highlight position 0.
  let m =
    combobox.select(combobox.open(model()), combobox.Item(1, "Apple", False))
    |> combobox.open
  combobox.option(
    anatomy(),
    combobox.Model(..m, active_index: Some(0)),
    0,
    combobox.Item(1, "Apple", False),
    [],
    [
      element.text("Apple"),
    ],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_base_ui combobox option — selected + highlighted")
}

pub fn render_option_disabled_test() {
  combobox.option(anatomy(), model(), 2, combobox.Item(9, "Soldout", True), [], [
    element.text("Soldout"),
  ])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_base_ui combobox option — disabled")
}

// =========================================================================
// PR 4 — multiple-select / chips + groups + async status
// =========================================================================

fn multi() -> combobox.Model(Int) {
  combobox.init(
    items: fruits(),
    config: combobox.Config(
      loop: True,
      auto_highlight: False,
      mode: combobox.Multiple,
      filter: combobox.Client,
      search_debounce: 0,
    ),
  )
}

fn grouped() -> combobox.Model(Int) {
  combobox.init_grouped(
    groups: [
      combobox.Group(label: "Citrus", items: [
        combobox.Item(1, "Lemon", False),
        combobox.Item(2, "Lime", False),
      ]),
      combobox.Group(label: "Berries", items: [
        combobox.Item(3, "Strawberry", False),
        combobox.Item(4, "Blueberry", False),
      ]),
    ],
    config: combobox.config(),
  )
}

// --- multiple-select toggle ----------------------------------------------

pub fn multiple_toggle_adds_and_keeps_open_test() {
  let t =
    combobox.toggle(combobox.open(multi()), combobox.Item(1, "Apple", False))
  assert t.selected == [1]
  assert t.open
}

pub fn multiple_toggle_twice_removes_test() {
  let t =
    combobox.open(multi())
    |> combobox.toggle(combobox.Item(1, "Apple", False))
    |> combobox.toggle(combobox.Item(1, "Apple", False))
  assert t.selected == []
}

pub fn multiple_toggle_appends_in_selection_order_test() {
  let t =
    combobox.open(multi())
    |> combobox.toggle(combobox.Item(3, "Banana", False))
    |> combobox.toggle(combobox.Item(1, "Apple", False))
  assert t.selected == [3, 1]
}

pub fn multiple_toggle_resets_active_filter_test() {
  // Typed "ap", then toggle Apple → filter clears, highlight drops, stays open.
  let t =
    combobox.set_query(multi(), "ap")
    |> combobox.toggle(combobox.Item(1, "Apple", False))
  assert t.selected == [1]
  assert t.query == ""
  assert t.input_value == ""
  assert t.active_index == None
  assert t.open
}

pub fn multiple_toggle_keeps_highlight_without_filter_test() {
  // No query → highlight stays put so repeated Enter toggles the same row.
  let t =
    combobox.move(combobox.open(multi()), combobox.First)
    |> combobox.toggle(combobox.Item(1, "Apple", False))
  assert t.active_index == Some(0)
  assert t.query == ""
}

// --- chip removal --------------------------------------------------------

pub fn remove_selected_at_test() {
  let m = combobox.Model(..multi(), selected: [1, 2, 3])
  assert combobox.remove_selected_at(m, 1).selected == [1, 3]
}

pub fn remove_selected_at_out_of_range_is_noop_test() {
  let m = combobox.Model(..multi(), selected: [1, 2, 3])
  assert combobox.remove_selected_at(m, 9).selected == [1, 2, 3]
}

pub fn remove_last_selected_test() {
  let m = combobox.Model(..multi(), selected: [1, 2, 3])
  assert combobox.remove_last_selected(m).selected == [1, 2]
}

pub fn remove_last_selected_empty_is_noop_test() {
  assert combobox.remove_last_selected(multi()).selected == []
}

// --- selectors -----------------------------------------------------------

pub fn selected_items_in_order_test() {
  let m = combobox.Model(..multi(), selected: [3, 1])
  assert combobox.selected_items(m)
    == [combobox.Item(3, "Banana", False), combobox.Item(1, "Apple", False)]
}

pub fn selected_value_first_test() {
  assert combobox.selected_value(combobox.Model(..multi(), selected: [2, 3]))
    == Some(2)
  assert combobox.selected_value(multi()) == None
}

pub fn is_selected_multiple_test() {
  let m = combobox.Model(..multi(), selected: [1, 3])
  assert combobox.is_selected(m, 1)
  assert combobox.is_selected(m, 3)
  assert !combobox.is_selected(m, 2)
}

pub fn has_selection_test() {
  assert !combobox.has_selection(multi())
  assert combobox.has_selection(combobox.Model(..multi(), selected: [1]))
}

pub fn selection_mode_test() {
  assert combobox.selection_mode(multi()) == combobox.Multiple
  assert combobox.selection_mode(model()) == combobox.Single
}

// --- multiple-select update transitions ----------------------------------

pub fn update_option_chosen_multiple_toggles_and_stays_open_test() {
  let #(on, _) =
    combobox.update(anatomy(), combobox.open(multi()), combobox.OptionChosen(0))
  assert on.selected == [1]
  assert on.open
  let #(off, _) = combobox.update(anatomy(), on, combobox.OptionChosen(0))
  assert off.selected == []
  assert off.open
}

pub fn update_chip_removed_test() {
  let m = combobox.Model(..multi(), selected: [1, 2, 3])
  let #(next, _) = combobox.update(anatomy(), m, combobox.ChipRemoved(0))
  assert next.selected == [2, 3]
}

pub fn update_last_chip_removed_test() {
  let m = combobox.Model(..multi(), selected: [1, 2])
  let #(next, _) = combobox.update(anatomy(), m, combobox.LastChipRemoved)
  assert next.selected == [1]
}

// --- groups --------------------------------------------------------------

pub fn visible_groups_buckets_with_flat_positions_test() {
  assert combobox.visible_groups(grouped())
    == [
      #("Citrus", [
        #(0, combobox.Item(1, "Lemon", False)),
        #(1, combobox.Item(2, "Lime", False)),
      ]),
      #("Berries", [
        #(2, combobox.Item(3, "Strawberry", False)),
        #(3, combobox.Item(4, "Blueberry", False)),
      ]),
    ]
}

pub fn visible_groups_drops_empty_group_test() {
  // "li" matches only Lime (Citrus); Berries fully filters out and disappears.
  assert combobox.visible_groups(combobox.set_query(grouped(), "li"))
    == [#("Citrus", [#(0, combobox.Item(2, "Lime", False))])]
}

pub fn visible_groups_flat_list_is_empty_test() {
  assert combobox.visible_groups(model()) == []
}

// --- async status --------------------------------------------------------

pub fn set_loading_test() {
  assert combobox.set_loading(model(), True).loading
  assert !combobox.set_loading(combobox.set_loading(model(), True), False).loading
}

// --- new ARIA render contracts (birdie) ----------------------------------

pub fn render_list_multiselectable_test() {
  combobox.list(anatomy(), combobox.Multiple, [], [])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_base_ui combobox list — multiselectable")
}

pub fn render_group_test() {
  combobox.group(anatomy(), 0, [], [
    combobox.group_label(anatomy(), 0, [], [element.text("Citrus")]),
  ])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_base_ui combobox group — role + labelledby")
}

pub fn render_status_test() {
  combobox.status([], [element.text("Loading…")])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_base_ui combobox status — polite live region")
}

pub fn render_chip_remove_test() {
  html.button(combobox.chip_remove_attributes(0, "Apple"), [element.text("×")])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_base_ui combobox chip-remove — labelled button")
}

// =========================================================================
// Remote / server-driven (Manual filter, set/append items, pagination)
// =========================================================================

fn remote() -> combobox.Model(Int) {
  combobox.init(
    items: [],
    config: combobox.Config(
      loop: True,
      auto_highlight: False,
      mode: combobox.Single,
      filter: combobox.Manual,
      search_debounce: 0,
    ),
  )
}

pub fn manual_filter_does_not_filter_test() {
  // Manual mode: a typed query does NOT drop items (the server already filtered).
  let m = combobox.set_items(remote(), fruits()) |> combobox.set_query("zzz")
  assert combobox.visible_count(m) == 4
}

pub fn client_filter_still_filters_test() {
  // Sanity: the default (Client) mode still substring-filters.
  assert combobox.visible_count(combobox.set_query(model(), "zzz")) == 0
}

pub fn set_items_replaces_and_drops_highlight_test() {
  let m =
    combobox.set_items(remote(), fruits())
    |> combobox.move(combobox.First)
  assert m.active_index == Some(0)
  let next = combobox.set_items(m, [combobox.Item(9, "Mango", False)])
  assert next.items == [combobox.Item(9, "Mango", False)]
  assert next.active_index == None
}

pub fn append_items_keeps_highlight_test() {
  let m =
    combobox.set_items(remote(), fruits())
    |> combobox.move(combobox.First)
  let next = combobox.append_items(m, [combobox.Item(9, "Mango", False)])
  assert combobox.visible_count(next) == 5
  // Highlight survives a page append (keyboard position kept).
  assert next.active_index == Some(0)
}

pub fn is_reached_end_test() {
  assert combobox.is_reached_end(combobox.ReachedEnd)
  assert !combobox.is_reached_end(combobox.MoveNext)
}

pub fn update_reached_end_is_noop_test() {
  let m = combobox.set_items(remote(), fruits())
  let #(next, _) = combobox.update(anatomy(), m, combobox.ReachedEnd)
  assert next == m
}

pub fn search_request_reads_query_test() {
  assert combobox.search_request(combobox.SearchRequested("re")) == Some("re")
  assert combobox.search_request(combobox.MoveNext) == None
}

pub fn update_search_requested_is_noop_test() {
  let m = combobox.set_items(remote(), fruits())
  let #(next, _) = combobox.update(anatomy(), m, combobox.SearchRequested("re"))
  assert next == m
}

pub fn manual_input_sets_value_immediately_and_loads_test() {
  // Manual mode: typing updates the value NOW (controlled, no lag) and flips the
  // loading flag (the spinner shows during the debounce). `search_debounce: 0`
  // here, so the SearchRequested would fire immediately via the effect.
  let #(m, _) =
    combobox.update(anatomy(), remote(), combobox.InputChanged("re"))
  assert m.input_value == "re"
  assert m.query == "re"
  assert m.loading
}

pub fn client_input_does_not_set_loading_test() {
  // Client mode: typing filters locally, no remote search, no loading flag.
  let #(m, _) = combobox.update(anatomy(), model(), combobox.InputChanged("ap"))
  assert m.input_value == "ap"
  assert !m.loading
}

pub fn manual_input_dedups_on_trimmed_query_test() {
  // First search for "re" sets loading; adding a trailing space (same trimmed
  // query) updates the value but does NOT re-search (loading stays cleared).
  let #(searched, _) =
    combobox.update(anatomy(), remote(), combobox.InputChanged("re"))
  assert searched.loading
  let settled = combobox.set_loading(searched, False)
  let #(again, _) =
    combobox.update(anatomy(), settled, combobox.InputChanged("re "))
  assert again.input_value == "re "
  // No new search → loading not re-raised.
  assert !again.loading
}

//// Render contracts for the **styled** combobox (`gg_ui/ui/combobox`) — the
//// `cn-*` markup the headless behaviour gets dressed in: the input's chevron-vs-
//// clear affordance, the popup's items + check indicator, the empty message, and
//// the assembled widget. The headless state machine + ARIA is covered by
//// `gg_base_ui`'s 45 tests; this file pins only what *this* layer adds.
////
//// `gg_base_ui` is imported solely to *drive model states* the facade (rule 2)
//// deliberately doesn't re-export as constructors — `Msg` is an opaque alias, so
//// a styled-only caller can't build `OptionChosen`/`InputChanged`. Feeding them
//// to `combobox.update` (the public entry) keeps every rendered subject the
//// styled layer's own output.

import birdie
import gg_base_ui/combobox/combobox as base_combobox
import gg_ui/positioning
import gg_ui/ui/combobox
import lustre/element

fn fruits() -> List(combobox.Item(Int)) {
  [
    combobox.Item(value: 1, label: "Apple", disabled: False),
    combobox.Item(value: 2, label: "Apricot", disabled: False),
    combobox.Item(value: 3, label: "Banana", disabled: False),
  ]
}

fn anatomy() -> combobox.Anatomy {
  combobox.anatomy_with_id("cb")
}

fn model() -> combobox.Model(Int) {
  combobox.init(items: fruits(), config: combobox.config())
}

// Open, then choose visible position 0 (Apple) — a real selection driven through
// the public `update`, used by the clear-affordance + selected-option snapshots.
fn with_selection() -> combobox.Model(Int) {
  let a = anatomy()
  let #(opened, _) =
    combobox.update(a, model(), base_combobox.ListToggled(True))
  let #(chosen, _) = combobox.update(a, opened, base_combobox.OptionChosen(0))
  chosen
}

// Filter to a query that matches nothing → the empty branch of `content`.
fn no_matches() -> combobox.Model(Int) {
  let #(m, _) =
    combobox.update(anatomy(), model(), base_combobox.InputChanged("zzz"))
  m
}

// --- input affordance: chevron vs clear ----------------------------------

pub fn input_chevron_affordance_test() {
  // Default: nothing selected → the decorative-but-clickable chevron trigger.
  combobox.input(
    anatomy(),
    model(),
    placeholder: "Search…",
    clearable: False,
    attrs: [],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui combobox input — chevron affordance")
}

pub fn input_clear_affordance_test() {
  // `clearable` + a selection → shadcn swaps the chevron for a clear ✕ button.
  combobox.input(
    anatomy(),
    with_selection(),
    placeholder: "Search…",
    clearable: True,
    attrs: [],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui combobox input — clear affordance")
}

// --- popup content: items, selected indicator, empty ---------------------

pub fn content_items_test() {
  combobox.content(
    anatomy(),
    model(),
    side: positioning.Bottom,
    align: positioning.Start,
    empty_label: "No fruit found.",
    loading_label: "Loading…",
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui combobox content — items + check indicator")
}

pub fn content_selected_option_test() {
  // Apple selected → its option carries `aria-selected="true"` (CSS reveals the
  // built-in check indicator off that).
  combobox.content(
    anatomy(),
    with_selection(),
    side: positioning.Bottom,
    align: positioning.Start,
    empty_label: "No fruit found.",
    loading_label: "Loading…",
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui combobox content — selected option")
}

pub fn content_empty_test() {
  combobox.content(
    anatomy(),
    no_matches(),
    side: positioning.Bottom,
    align: positioning.Start,
    empty_label: "No fruit found.",
    loading_label: "Loading…",
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui combobox content — empty message")
}

// --- multiple-select: chips + multiselectable ----------------------------

fn multi_config() -> combobox.Config {
  combobox.Config(loop: True, auto_highlight: False, mode: combobox.Multiple)
}

// A multiple-select model with Apple + Banana already picked.
fn multi_selected() -> combobox.Model(Int) {
  let a = anatomy()
  let m = combobox.init(items: fruits(), config: multi_config())
  let #(m, _) = combobox.update(a, m, base_combobox.ListToggled(True))
  let #(m, _) = combobox.update(a, m, base_combobox.OptionChosen(0))
  let #(m, _) = combobox.update(a, m, base_combobox.OptionChosen(2))
  m
}

pub fn input_chips_test() {
  // Multiple mode with selections → the chips render leading, each with a remove
  // button; the trailing affordance stays the chevron (nothing typed).
  combobox.input(
    anatomy(),
    multi_selected(),
    placeholder: "Search…",
    clearable: False,
    attrs: [],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui combobox input — multiple-select chips")
}

pub fn content_multiselectable_test() {
  // The listbox advertises multi-select; the picked options are aria-selected.
  combobox.content(
    anatomy(),
    multi_selected(),
    side: positioning.Bottom,
    align: positioning.Start,
    empty_label: "No fruit found.",
    loading_label: "Loading…",
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui combobox content — multiselectable + selected")
}

// --- grouped list --------------------------------------------------------

fn grouped() -> combobox.Model(Int) {
  combobox.init_grouped(
    groups: [
      combobox.Group(label: "Citrus", items: [
        combobox.Item(value: 1, label: "Lemon", disabled: False),
        combobox.Item(value: 2, label: "Lime", disabled: False),
      ]),
      combobox.Group(label: "Berries", items: [
        combobox.Item(value: 3, label: "Strawberry", disabled: False),
      ]),
    ],
    config: combobox.config(),
  )
}

pub fn content_grouped_test() {
  combobox.content(
    anatomy(),
    grouped(),
    side: positioning.Bottom,
    align: positioning.Start,
    empty_label: "No fruit found.",
    loading_label: "Loading…",
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui combobox content — grouped sections")
}

// --- async status --------------------------------------------------------

pub fn content_loading_test() {
  combobox.content(
    anatomy(),
    combobox.set_loading(model(), True),
    side: positioning.Bottom,
    align: positioning.Start,
    empty_label: "No fruit found.",
    loading_label: "Loading…",
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui combobox content — loading status")
}

// --- assembled widget ----------------------------------------------------

pub fn combobox_widget_test() {
  combobox.combobox(
    anatomy: anatomy(),
    model: model(),
    placeholder: "Search…",
    side: positioning.Bottom,
    align: positioning.Start,
    clearable: False,
    empty_label: "No fruit found.",
    loading_label: "Loading…",
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui combobox widget — field + popup")
}

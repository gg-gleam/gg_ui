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
import gleam/list
import lustre/element
import lustre/element/html

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

// Compose the parts the way a consumer would — popup = loading? + empty + list,
// the list filled flat (`options`) or sectioned (`groups`). One helper so the
// content snapshots keep pinning the assembled output across the variants.
fn assemble(model: combobox.Model(Int)) -> element.Element(combobox.Msg) {
  let a = anatomy()
  let grouped =
    combobox.groups(model, fn(lbl, entries, gi) {
      combobox.group(
        a,
        gi,
        [],
        list.flatten([
          [combobox.label(a, gi, [], [html.text(lbl)])],
          list.map(entries, fn(e) { combobox.option(a, model, e.0, e.1) }),
        ]),
      )
    })
  let body = case grouped {
    [] -> combobox.options(a, model)
    _ -> grouped
  }
  let loading = case combobox.is_loading(model) {
    True -> [combobox.loading([], [html.text("Loading…")])]
    False -> []
  }
  combobox.content(
    a,
    model,
    side: positioning.Bottom,
    align: positioning.Start,
    attrs: [],
    children: list.flatten([
      loading,
      [combobox.empty([], [html.text("No fruit found.")])],
      [combobox.list(a, model, [], body)],
    ]),
  )
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
  assemble(model())
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui combobox content — items + check indicator")
}

pub fn content_selected_option_test() {
  // Apple selected → its option carries `aria-selected="true"` (CSS reveals the
  // built-in check indicator off that).
  assemble(with_selection())
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui combobox content — selected option")
}

pub fn content_empty_test() {
  assemble(no_matches())
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
  assemble(multi_selected())
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
  assemble(grouped())
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui combobox content — grouped sections")
}

// --- grouped + multiple (composes — independent axes, like Base UI) -------

// A grouped, multiple-select model with Lemon + Strawberry picked across groups.
fn grouped_multi() -> combobox.Model(Int) {
  let a = anatomy()
  let m =
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
      config: multi_config(),
    )
  let #(m, _) = combobox.update(a, m, base_combobox.ListToggled(True))
  // Visible positions 0 (Lemon) and 2 (Strawberry) — across the two groups.
  let #(m, _) = combobox.update(a, m, base_combobox.OptionChosen(0))
  let #(m, _) = combobox.update(a, m, base_combobox.OptionChosen(2))
  m
}

pub fn content_grouped_multiselectable_test() {
  // Grouped sections AND `aria-multiselectable`, with the picks `aria-selected`
  // across groups — the two axes compose.
  assemble(grouped_multi())
  |> element.to_readable_string
  |> birdie.snap(
    title: "gg_ui combobox content — grouped + multiselectable + selected",
  )
}

pub fn input_grouped_multi_chips_test() {
  // The field is the chips field regardless of grouping — the picks from both
  // groups render as chips.
  combobox.input(
    anatomy(),
    grouped_multi(),
    placeholder: "Search…",
    clearable: False,
    attrs: [],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui combobox input — grouped + multiple chips")
}

// --- async status --------------------------------------------------------

pub fn content_loading_test() {
  assemble(combobox.set_loading(model(), True))
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui combobox content — loading status")
}

// --- assembled widget (composition: field + popup) -----------------------

pub fn combobox_widget_test() {
  let m = model()
  html.div([], [
    combobox.input(
      anatomy(),
      m,
      placeholder: "Search…",
      clearable: False,
      attrs: [],
    ),
    assemble(m),
  ])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui combobox widget — field + popup")
}

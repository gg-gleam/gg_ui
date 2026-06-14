//// Headless combobox — a Lustre port of Base UI's `Combobox.*`. **The kit's
//// first stateful component**: unlike popover/tooltip (native-first, render-once,
//// no model), a combobox has *no* native primitive — filtering, active-descendant
//// highlight, and listbox ARIA must run in a `Model`/`Msg`/`update`/`view`
//// component. See [`dev-docs/stateful-components.md`](../../../../dev-docs/stateful-components.md).
////
//// This module is the **pure core** (PR 1 of the port): the state record and the
//// pure transitions over it — filtering and highlight navigation — with **no
//// DOM, no effects, no ARIA**. It compiles and behaves identically on JS and the
//// BEAM (rule 3), and is exhaustively unit-tested, because the cross-target risk
//// lives here. The effectful shell (the Lustre component: `update` wiring,
//// listbox/option ARIA, the scroll-into-view / focus / anchor-width FFI) layers
//// on top in a later PR and is the *only* place DOM enters.
////
//// Base UI mapping (the parts this core feeds, added later): `Root` owns this
//// `Model`; `Input` dispatches `set_query`; `List`/`Item` render `visible`;
//// keyboard maps to `move` / `select_active`; `Value`/`Empty` read the selectors.
////
//// Single-select only for now (Base UI's `selectionMode='single'`); multiple /
//// chips come in a later PR. `SelectionMode` is declared so the shell and the
//// styled facade can pin the axis from the start.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

// --- Items ---------------------------------------------------------------

/// One option in the list: the opaque `value` the caller selects, the `label`
/// shown + filtered against, and whether it's `disabled` (skipped by navigation
/// and not selectable). Mirrors a Base UI collection item.
pub type Item(value) {
  Item(value: value, label: String, disabled: Bool)
}

// --- Config --------------------------------------------------------------

/// Behaviour switches, defaulted to Base UI's. `loop` = arrow navigation wraps
/// past the ends (`loopFocus`, default on). `auto_highlight` = the first match is
/// highlighted as you type (`autoHighlight`, default off).
pub type Config {
  Config(loop: Bool, auto_highlight: Bool)
}

/// Base UI's defaults: looping navigation, no auto-highlight.
pub fn config() -> Config {
  Config(loop: True, auto_highlight: False)
}

/// Base UI's `selectionMode`. Only `Single` is wired today; `Multiple` is
/// declared so the shell/facade can name the axis (chips land later).
pub type SelectionMode {
  Single
  Multiple
}

// --- Navigation ----------------------------------------------------------

/// A highlight move over the *visible* (filtered) list. `Next`/`Previous` are
/// the arrow keys; `First`/`Last` are Home/End.
pub type Nav {
  First
  Last
  Next
  Previous
}

// --- Model ---------------------------------------------------------------

/// The combobox's state. `query` is the filter text (what the user typed);
/// `input_value` is what the field displays (equal to `query` while typing, the
/// chosen label after a selection). `active_index` highlights an entry in the
/// **visible** list (post-filter), not `items`. `selected` is the chosen value.
pub type Model(value) {
  Model(
    open: Bool,
    query: String,
    input_value: String,
    items: List(Item(value)),
    active_index: Option(Int),
    selected: Option(value),
    config: Config,
  )
}

/// A fresh, closed, empty-query model over `items` with the given `config`.
pub fn init(
  items items: List(Item(value)),
  config config: Config,
) -> Model(value) {
  Model(
    open: False,
    query: "",
    input_value: "",
    items:,
    active_index: None,
    selected: None,
    config:,
  )
}

// --- Filtering (pure) ----------------------------------------------------

/// Whether `label` matches `query`. Empty query matches everything (Base UI).
///
/// Base UI uses `Intl.Collator` with `sensitivity: 'base'` — case- *and*
/// accent-insensitive. This first cut is case-insensitive **substring** matching
/// (`string.lowercase` + `string.contains`), which is pure Gleam and identical on
/// both targets. Diacritic-folding (`é` ≡ `e`) is the one piece deferred — it
/// needs Unicode normalisation we don't pull in yet — and is tracked as a
/// refinement, not a behaviour we silently diverge on per target.
pub fn matches(label label: String, query query: String) -> Bool {
  query == ""
  || string.contains(
    does: string.lowercase(label),
    contain: string.lowercase(query),
  )
}

/// The visible list: `items` filtered by the current `query`, each paired with
/// its **original index** in `items` (option ids / value lookup need the stable
/// index, which filtering would otherwise lose).
pub fn visible(model: Model(value)) -> List(#(Int, Item(value))) {
  model.items
  |> list.index_map(fn(item, index) { #(index, item) })
  |> list.filter(fn(pair) {
    matches(label: { pair.1 }.label, query: model.query)
  })
}

/// How many entries the visible list has.
pub fn visible_count(model: Model(value)) -> Int {
  list.length(visible(model))
}

/// The visible entry currently highlighted, if any.
pub fn active_item(model: Model(value)) -> Option(Item(value)) {
  case model.active_index {
    None -> None
    Some(index) ->
      visible(model)
      |> list.drop(index)
      |> list.first
      |> option.from_result
      |> option.map(fn(pair) { pair.1 })
  }
}

// --- Highlight navigation (pure) -----------------------------------------

/// Resolve a `Nav` move against a list of `count` entries, honouring `loop`.
/// `None` (nothing highlighted) seeds from the natural end: `Next`/`First` →
/// first, `Previous`/`Last` → last. Returns `None` only for an empty list.
pub fn navigate(
  active active: Option(Int),
  nav nav: Nav,
  count count: Int,
  loop loop: Bool,
) -> Option(Int) {
  case count {
    0 -> None
    _ ->
      case nav {
        First -> Some(0)
        Last -> Some(count - 1)
        Next ->
          case active {
            None -> Some(0)
            Some(i) if i >= count - 1 ->
              case loop {
                True -> Some(0)
                False -> Some(count - 1)
              }
            Some(i) -> Some(i + 1)
          }
        Previous ->
          case active {
            None -> Some(count - 1)
            Some(i) if i <= 0 ->
              case loop {
                True -> Some(count - 1)
                False -> Some(0)
              }
            Some(i) -> Some(i - 1)
          }
      }
  }
}

// --- Transitions (pure) --------------------------------------------------
//
// Each returns a new Model; the effectful shell maps a Msg to one of these and
// adds the DOM effect (scroll the active option into view, focus, …) around it.

/// Open the list.
pub fn open(model: Model(value)) -> Model(value) {
  Model(..model, open: True)
}

/// Close the list and drop the highlight (selection + input value are kept).
pub fn close(model: Model(value)) -> Model(value) {
  Model(..model, open: False, active_index: None)
}

/// The user typed: set the filter `query` and the displayed `input_value` to the
/// text, open the list, and re-seat the highlight. `auto_highlight` lands on the
/// first match; otherwise the highlight clears (a stale index would point at the
/// wrong post-filter row).
pub fn set_query(model: Model(value), query: String) -> Model(value) {
  let next = Model(..model, query:, input_value: query, open: True)
  let active = case model.config.auto_highlight, visible_count(next) {
    True, count if count > 0 -> Some(0)
    _, _ -> None
  }
  Model(..next, active_index: active)
}

/// Move the highlight (arrow / Home / End) over the visible list.
pub fn move(model: Model(value), nav: Nav) -> Model(value) {
  let active =
    navigate(
      active: model.active_index,
      nav:,
      count: visible_count(model),
      loop: model.config.loop,
    )
  Model(..model, active_index: active)
}

/// Select the highlighted entry (Enter / click on the active option). On a hit:
/// record the value, fill the input with its label, and close. Returns the new
/// model and the chosen value (`None` if nothing was highlighted) so the shell
/// can notify a controlled parent.
pub fn select_active(model: Model(value)) -> #(Model(value), Option(value)) {
  case active_item(model) {
    None -> #(model, None)
    Some(item) -> #(select(model, item), Some(item.value))
  }
}

/// Select a specific `item` (e.g. a pointer click that already knows the row):
/// record value, fill input with the label, close, clear the query so a reopen
/// shows the full list.
pub fn select(model: Model(value), item: Item(value)) -> Model(value) {
  Model(
    ..model,
    selected: Some(item.value),
    input_value: item.label,
    query: "",
    open: False,
    active_index: None,
  )
}

// --- Selectors (pure reads) ----------------------------------------------

/// Whether `value` is the current selection (drives an item's `aria-selected` /
/// check indicator). Uses Gleam structural equality — a faithful stand-in for
/// Base UI's `isItemEqualToValue` for plain value types.
pub fn is_selected(model: Model(value), value: value) -> Bool {
  model.selected == Some(value)
}

/// Whether the visible list is empty (drives the `Empty` part).
pub fn is_empty(model: Model(value)) -> Bool {
  visible_count(model) == 0
}

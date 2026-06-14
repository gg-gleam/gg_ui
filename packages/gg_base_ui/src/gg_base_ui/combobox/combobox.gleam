//// Headless combobox — a Lustre port of Base UI's `Combobox.*`. **The kit's
//// first stateful component**: unlike popover/tooltip (native-first, render-once,
//// no model), a combobox has *no* native primitive — filtering, active-descendant
//// highlight, and listbox ARIA must run in a `Model`/`Msg`/`update`/`view`
//// component. See [`dev-docs/stateful-components.md`](../../../../dev-docs/stateful-components.md).
////
//// The module has two clearly-separated halves (see
//// [`dev-docs/stateful-components.md`](../../../../dev-docs/stateful-components.md)):
////
//// 1. **Pure core** — the state record and the pure transitions over it
////    (filtering, highlight navigation, open/close/query/select) with **no DOM,
////    no effects, no ARIA**. It behaves identically on JS and the BEAM (rule 3)
////    and is where the cross-target risk lives, so it's exhaustively unit-tested.
//// 2. **Effectful shell** — the Lustre component: `Anatomy`, `Msg`, `update`
////    (core transition + DOM effect), and the listbox/option `view` parts with
////    their ARIA. This is the **only** place DOM enters — event wiring, native
////    popover show/hide, and the scroll-into-view / focus FFI. The host embeds it
////    as an MVU module (its model holds a `Model(value)` + an `Anatomy`; its
////    update threads `Msg` through `update`).
////
//// Base UI mapping (the parts this core feeds, added later): `Root` owns this
//// `Model`; `Input` dispatches `set_query`; `List`/`Item` render `visible`;
//// keyboard maps to `move` / `select_active`; `Value`/`Empty` read the selectors.
////
//// Single-select only for now (Base UI's `selectionMode='single'`); multiple /
//// chips come in a later PR. `SelectionMode` is declared so the shell and the
//// styled facade can pin the axis from the start.

import gg_base_ui/helpers/id_gen/id_gen
import gg_base_ui/positioning/positioning.{type Placement}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute.{type Attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

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

// =========================================================================
// EFFECTFUL SHELL — the Lustre component (Anatomy / Msg / update / view)
// =========================================================================
//
// The only place DOM enters. Drives the pure core above and adds event wiring,
// listbox/option ARIA, native-popover show/hide, and the scroll/focus FFI.

// --- Anatomy -------------------------------------------------------------

/// The stable ids the parts share. Mint **once** (the `useId` analogue) and keep
/// it in the host model; never recompute per render.
pub type Anatomy {
  Anatomy(input_id: String, listbox_id: String, label_id: String)
}

/// Build an `Anatomy` with a fresh, collision-free base id (the default).
pub fn anatomy() -> Anatomy {
  anatomy_with_id(id_gen.generate_with_prefix("combobox"))
}

/// Build an `Anatomy` from an explicit base id — for tests or pinning across a
/// server/client render boundary. The caller owns uniqueness.
pub fn anatomy_with_id(id: String) -> Anatomy {
  Anatomy(
    input_id: id <> "-input",
    listbox_id: id <> "-listbox",
    label_id: id <> "-label",
  )
}

/// Stable id for the option at visible position `pos` — the target of the
/// input's `aria-activedescendant` and the option's own `id`.
pub fn option_id(anatomy: Anatomy, pos: Int) -> String {
  anatomy.listbox_id <> "-option-" <> int.to_string(pos)
}

// --- Msg -----------------------------------------------------------------

/// What the component handles. The host threads these through `update`; it never
/// constructs them by hand (the view parts wire the events), so a styled facade
/// can keep `Msg` opaque.
pub type Msg {
  /// The input's text changed (`on_input`): re-filter + open.
  InputChanged(String)
  /// ArrowDown — highlight the next visible option (opening if closed).
  MoveNext
  /// ArrowUp — highlight the previous visible option.
  MovePrevious
  /// Home — highlight the first visible option.
  MoveFirst
  /// End — highlight the last visible option.
  MoveLast
  /// Enter — select the highlighted option.
  ChooseActive
  /// Escape — close without selecting.
  Dismissed
  /// A pointer click on the visible option at this position.
  OptionChosen(Int)
  /// Hover moved onto the visible option at this position (highlight follows).
  OptionHighlighted(Int)
  /// The native popover's `toggle` fired (`True` open / `False` closed) — keeps
  /// the model in sync when the browser light-dismisses.
  ListToggled(Bool)
  /// The input gained focus / was clicked — open the list.
  OpenRequested
}

// --- update --------------------------------------------------------------

/// Map a `Msg` to a pure core transition plus any DOM effect (native popover
/// show/hide, scroll the active option into view, focus the input). Returns the
/// new model and its effect; the host inspects `model.selected` for the choice.
pub fn update(
  anatomy: Anatomy,
  model: Model(value),
  msg: Msg,
) -> #(Model(value), Effect(Msg)) {
  case msg {
    InputChanged(text) -> #(set_query(model, text), show(anatomy))
    MoveNext -> navigated(anatomy, model, Next)
    MovePrevious -> navigated(anatomy, model, Previous)
    MoveFirst -> navigated(anatomy, model, First)
    MoveLast -> navigated(anatomy, model, Last)
    ChooseActive -> {
      let #(next, _) = select_active(model)
      #(next, hide(anatomy))
    }
    Dismissed -> #(close(model), hide(anatomy))
    OptionChosen(pos) -> {
      let #(next, _) = select_active(Model(..model, active_index: Some(pos)))
      #(next, hide(anatomy))
    }
    OptionHighlighted(pos) -> #(
      Model(..model, active_index: Some(pos)),
      effect.none(),
    )
    ListToggled(True) -> #(open(model), effect.none())
    ListToggled(False) -> #(close(model), effect.none())
    OpenRequested -> #(
      open(model),
      effect.batch([show(anatomy), focus(anatomy)]),
    )
  }
}

// Arrow / Home / End: open (if needed), move the highlight, then show + scroll
// the now-active option into view.
fn navigated(
  anatomy: Anatomy,
  model: Model(value),
  nav: Nav,
) -> #(Model(value), Effect(Msg)) {
  let next = move(open(model), nav)
  #(next, effect.batch([show(anatomy), scroll_active(anatomy, next)]))
}

fn scroll_active(anatomy: Anatomy, model: Model(value)) -> Effect(Msg) {
  case model.active_index {
    Some(pos) ->
      effect.from(fn(_dispatch) {
        scroll_option_into_view(option_id(anatomy, pos))
      })
    None -> effect.none()
  }
}

fn show(anatomy: Anatomy) -> Effect(Msg) {
  effect.from(fn(_dispatch) { show_listbox(anatomy.listbox_id) })
}

fn hide(anatomy: Anatomy) -> Effect(Msg) {
  effect.from(fn(_dispatch) { hide_listbox(anatomy.listbox_id) })
}

fn focus(anatomy: Anatomy) -> Effect(Msg) {
  effect.from(fn(_dispatch) { focus_input(anatomy.input_id) })
}

// --- view parts ----------------------------------------------------------

/// The combobox `<input>` — `role="combobox"` wired to the listbox + the active
/// option, with the text + keyboard behaviour. Merge styling via `attrs`. The
/// anchor for the listbox's positioning is this element.
pub fn input(
  anatomy: Anatomy,
  model: Model(value),
  attrs: List(Attribute(Msg)),
) -> Element(Msg) {
  html.input(
    list.flatten([
      [
        attribute.id(anatomy.input_id),
        attribute.attribute("role", "combobox"),
        attribute.attribute("aria-autocomplete", "list"),
        attribute.attribute("aria-expanded", bool_attr(model.open)),
        attribute.attribute("aria-controls", anatomy.listbox_id),
        attribute.value(model.input_value),
        positioning.anchor_style(anatomy.input_id),
        event.on_input(InputChanged),
        event.advanced("keydown", keydown_handler()),
        event.on_focus(OpenRequested),
      ],
      active_descendant(anatomy, model),
      attrs,
    ]),
  )
}

/// The popup `role="listbox"`, a native `popover="auto"` anchored to the input
/// (top layer + light-dismiss for free). `placement` / `side_offset` reuse
/// `gg_base_ui/positioning`. Pass the `option`s as children.
pub fn listbox(
  anatomy: Anatomy,
  placement: Placement,
  side_offset: Int,
  attrs: List(Attribute(Msg)),
  options: List(Element(Msg)),
) -> Element(Msg) {
  html.div(
    list.flatten([
      [
        attribute.id(anatomy.listbox_id),
        attribute.attribute("role", "listbox"),
        attribute.attribute("popover", "auto"),
        attribute.attribute(
          "data-side",
          positioning.side_to_string(placement.side),
        ),
        attribute.attribute(
          "data-align",
          positioning.align_to_string(placement.align),
        ),
        event.on("toggle", toggle_decoder()),
      ],
      positioning.positioned_style(anatomy.input_id, placement, side_offset),
      attrs,
    ]),
    options,
  )
}

/// One `role="option"` at visible position `pos`. Carries `aria-selected`,
/// `data-highlighted` when active, and `data-disabled`/`aria-disabled`; clicking
/// selects, hovering highlights. `children` is the label (+ any indicator).
pub fn option(
  anatomy: Anatomy,
  model: Model(value),
  pos: Int,
  item: Item(value),
  attrs: List(Attribute(Msg)),
  children: List(Element(Msg)),
) -> Element(Msg) {
  html.div(
    list.flatten([
      [
        attribute.id(option_id(anatomy, pos)),
        attribute.attribute("role", "option"),
        attribute.attribute(
          "aria-selected",
          bool_attr(is_selected(model, item.value)),
        ),
        event.on_click(OptionChosen(pos)),
        event.on_mouse_enter(OptionHighlighted(pos)),
      ],
      highlighted_attr(model, pos),
      disabled_attr(item),
      attrs,
    ]),
    children,
  )
}

fn active_descendant(
  anatomy: Anatomy,
  model: Model(value),
) -> List(Attribute(Msg)) {
  case model.open, model.active_index {
    True, Some(pos) -> [
      attribute.attribute("aria-activedescendant", option_id(anatomy, pos)),
    ]
    _, _ -> []
  }
}

fn highlighted_attr(model: Model(value), pos: Int) -> List(Attribute(Msg)) {
  case model.active_index == Some(pos) {
    True -> [attribute.attribute("data-highlighted", "")]
    False -> []
  }
}

fn disabled_attr(item: Item(value)) -> List(Attribute(Msg)) {
  case item.disabled {
    True -> [
      attribute.attribute("data-disabled", ""),
      attribute.attribute("aria-disabled", "true"),
    ]
    False -> []
  }
}

fn bool_attr(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

fn keydown_handler() -> decode.Decoder(event.Handler(Msg)) {
  use key <- decode.field("key", decode.string)
  // Nav keys dispatch + preventDefault (stop the caret/page from also moving);
  // any other key fails the decoder, so typing flows through untouched.
  case key {
    "ArrowDown" -> decode.success(nav_handler(MoveNext))
    "ArrowUp" -> decode.success(nav_handler(MovePrevious))
    "Home" -> decode.success(nav_handler(MoveFirst))
    "End" -> decode.success(nav_handler(MoveLast))
    "Enter" -> decode.success(nav_handler(ChooseActive))
    "Escape" ->
      decode.success(event.handler(
        dispatch: Dismissed,
        prevent_default: False,
        stop_propagation: False,
      ))
    _ -> decode.failure(nav_handler(Dismissed), "combobox-ignored-key")
  }
}

fn nav_handler(msg: Msg) -> event.Handler(Msg) {
  event.handler(dispatch: msg, prevent_default: True, stop_propagation: False)
}

fn toggle_decoder() -> decode.Decoder(Msg) {
  use new_state <- decode.field("newState", decode.string)
  decode.success(ListToggled(new_state == "open"))
}

// --- FFI -----------------------------------------------------------------
//
// JS-only; the Erlang fallbacks never run (effects execute client-side), so an
// SSR render produces the markup with no client effect. Keep export names in
// sync with `combobox_ffi.ts`.

@external(javascript, "./combobox_ffi.ts", "showPopover")
fn show_listbox(_listbox_id: String) -> Nil {
  Nil
}

@external(javascript, "./combobox_ffi.ts", "hidePopover")
fn hide_listbox(_listbox_id: String) -> Nil {
  Nil
}

@external(javascript, "./combobox_ffi.ts", "scrollOptionIntoView")
fn scroll_option_into_view(_option_id: String) -> Nil {
  Nil
}

@external(javascript, "./combobox_ffi.ts", "focusInput")
fn focus_input(_input_id: String) -> Nil {
  Nil
}
